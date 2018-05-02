# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Safenet Luna HSM Java Security Provider support.
    class LunaSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        setup_ext_dir

        @droplet.copy_resources
        @droplet.security_providers << 'com.safenetinc.luna.provider.LunaProvider'
        @droplet.additional_libraries << luna_provider_jar if @droplet.java_home.java_9_or_later?

        credentials = @application.services.find_service(FILTER, 'client', 'servers', 'groups')['credentials']
        write_client credentials['client']
        write_servers credentials['servers']
        write_configuration credentials['servers'], credentials['groups']
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'ChrystokiConfigurationPath', @droplet.sandbox

        if @droplet.java_home.java_9_or_later?
          @droplet.additional_libraries << luna_provider_jar
        else
          @droplet.extension_directories << ext_dir
        end
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'client', 'servers', 'groups'
      end

      private

      FILTER = /luna/

      private_constant :FILTER

      def chrystoki
        @droplet.sandbox + 'Chrystoki.conf'
      end

      def client_certificate
        @droplet.sandbox + 'client-certificate.pem'
      end

      def client_private_key
        @droplet.sandbox + 'client-private-key.pem'
      end

      def ext_dir
        @droplet.sandbox + 'ext'
      end

      def luna_provider_jar
        @droplet.sandbox + 'jsp/LunaProvider.jar'
      end

      def luna_api_so
        @droplet.sandbox + 'jsp/64/libLunaAPI.so'
      end

      def lib_cryptoki
        @droplet.sandbox + 'libs/64/libCryptoki2.so'
      end

      def lib_cklog
        @droplet.sandbox + 'libs/64/libcklog2.so'
      end

      def setup_ext_dir
        FileUtils.mkdir ext_dir
        [luna_provider_jar, luna_api_so].each do |file|
          FileUtils.ln_s file.relative_path_from(ext_dir), ext_dir, force: true
        end
      end

      def logging?
        @configuration['logging_enabled']
      end

      def ha_logging?
        @configuration['ha_logging_enabled']
      end

      def tcp_keep_alive
        @configuration['tcp_keep_alive_enabled'] ? 1 : 0
      end

      def padded_index(index)
        index.to_s.rjust(2, '0')
      end

      def relative(path)
        path.relative_path_from(@droplet.root)
      end

      def server_certificates
        @droplet.sandbox + 'server-certificates.pem'
      end

      def write_client(client)
        FileUtils.mkdir_p client_certificate.parent
        client_certificate.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{client['certificate']}\n"
        end

        FileUtils.mkdir_p client_private_key.parent
        client_private_key.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{client['private-key']}\n"
        end
      end

      def write_configuration(servers, groups)
        chrystoki.open(File::APPEND | File::WRONLY) do |f|
          write_prologue f
          servers.each_with_index { |server, index| write_server f, index, server }
          f.write <<~TOKEN
            }

            VirtualToken = {
          TOKEN
          groups.each_with_index { |group, index| write_group f, index, group }
          write_epilogue f, groups
        end
      end

      def write_epilogue(f, groups)
        f.write <<~HA
          }

          HAConfiguration = {
            AutoReconnectInterval = 60;
            HAOnly                = 1;
            reconnAtt             = -1;
        HA
        write_ha_logging(f) if ha_logging?
        f.write <<~HA
          }

          HASynchronize = {
        HA
        groups.each { |group| f.write "  #{group['label']} = 1;\n" }
        f.write "}\n"
      end

      def write_group(f, index, group)
        padded_index = padded_index index

        f.write "  VirtualToken#{padded_index}Label   = #{group['label']};\n"
        f.write "  VirtualToken#{padded_index}SN      = 1#{group['members'][0]};\n"
        f.write "  VirtualToken#{padded_index}Members = #{group['members'].join(',')};\n"
        f.write "\n"
      end

      def write_lib(f)
        f.write <<~CONFIG

          Chrystoki2 = {
        CONFIG

        if logging?
          write_logging(f)
        else
          f.write <<~LIB
              LibUNIX64 = #{relative(lib_cryptoki)};
            }
          LIB
        end
      end

      def write_logging(f)
        f.write <<~LOGGING
            LibUNIX64 = #{relative(lib_cklog)};
          }

          CkLog2 = {
            Enabled      = 1;
            LibUNIX64    = #{relative(lib_cryptoki)};
            LoggingMask  = ALL_FUNC;
            LogToStreams = 1;
            NewFormat    = 1;
          }
        LOGGING
      end

      def write_ha_logging(f)
        f.write <<~HA
          haLogStatus           = enabled;
          haLogToStdout         = enabled;
        HA
      end

      def write_prologue(f)
        write_lib(f)

        f.write <<~CLIENT

          LunaSA Client = {
            TCPKeepAlive = #{tcp_keep_alive};
            NetClient    = 1;

            ClientCertFile    = #{relative(client_certificate)};
            ClientPrivKeyFile = #{relative(client_private_key)};
            HtlDir            = #{relative(@droplet.sandbox + 'htl')};
            ServerCAFile      = #{relative(server_certificates)};

        CLIENT
      end

      def write_server(f, index, server)
        padded_index = padded_index index

        f.write "  ServerName#{padded_index} = #{server['name']};\n"
        f.write "  ServerPort#{padded_index} = 1792;\n"
        f.write "  ServerHtl#{padded_index}  = 0;\n"
        f.write "\n"
      end

      def write_servers(servers)
        FileUtils.mkdir_p server_certificates.parent
        server_certificates.open(File::CREAT | File::WRONLY) do |f|
          servers.each { |server| f.write "#{server['certificate']}\n" }
        end
      end

    end
  end
end
