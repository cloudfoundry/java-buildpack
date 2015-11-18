# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2015 the original author or authors.
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
        download(@version, @uri) { |file| expand file }
        @droplet.copy_resources

        credentials = @application.services.find_service(FILTER)['credentials']
        write_client credentials['client']
        write_servers credentials['servers']
        write_configuration credentials['servers'], credentials['groups']
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'ChrystokiConfigurationPath', @droplet.sandbox

        @droplet.java_opts
          .add_system_property('java.security.properties', @droplet.sandbox + 'java.security')
          .add_system_property('java.ext.dirs', ext_dirs)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'client', 'servers', 'groups'
      end

      private

      FILTER = /luna/.freeze

      private_constant :FILTER

      def chrystoki
        @droplet.sandbox + 'Chrystoki.conf'
      end

      def client_certificate
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/client/client-certificate.pem'
      end

      def client_private_key
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/client/client-private-key.pem'
      end

      def expand(file)
        with_timing "Expanding Luna Client to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          Dir.mktmpdir do |root|
            root = Pathname.new(root)

            FileUtils.mkdir_p root
            shell "tar x#{compression_flag(file)}f #{file.path} -C #{root} --strip 3 2>&1"

            install_client root
          end
        end
      end

      def ext_dirs
        "#{qualify_path(@droplet.java_home.root + 'lib/ext', @droplet.root)}:" \
        "#{qualify_path(@droplet.sandbox + 'usr/safenet/lunaclient/jsp/lib', @droplet.root)}"
      end

      def install_client(root)
        FileUtils.mkdir_p @droplet.sandbox

        Dir.chdir(@droplet.sandbox) do
          shell "#{rpm2cpio} < #{libcrpytoki root} | cpio -id ./usr/safenet/lunaclient/lib/libCryptoki2_64.so"
          shell "#{rpm2cpio} < #{lunajsp root} | cpio -id ./usr/safenet/lunaclient/jsp/lib/*"
        end
      end

      def libcrpytoki(root)
        Dir[root + 'libcryptoki-*.x86_64.rpm'][0]
      end

      def lunajsp(root)
        Dir[root + 'lunajsp-*.x86_64.rpm'][0]
      end

      def padded_index(index)
        index.to_s.rjust(2, '0')
      end

      def relative(path)
        path.relative_path_from(@droplet.root)
      end

      def rpm2cpio
        Pathname.new(File.expand_path('../rpm2cpio.py', __FILE__))
      end

      def server_certificates
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/server/server-certificates.pem'
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
          f.write <<EOS
}

VirtualToken = {
EOS
          groups.each_with_index { |group, index| write_group f, index, group }
          write_epilogue f
        end
      end

      def write_epilogue(f)
        f.write <<EOS
}

HAConfiguration = {
  HAOnly = 1;
}
EOS
      end

      def write_group(f, index, group)
        padded_index = padded_index index

        f.write "  VirtualToken#{padded_index}Label   = #{group['label']};\n"
        f.write "  VirtualToken#{padded_index}SN      = 1#{group['members'][0]};\n"
        f.write "  VirtualToken#{padded_index}Members = #{group['members'].join(',')};\n"
        f.write "\n"
      end

      def write_prologue(f)
        f.write <<EOS

LunaSA Client = {
  NetClient = 1;

  ClientCertFile    = #{relative(@droplet.sandbox + 'usr/safenet/lunaclient/cert/client/client-certificate.pem')};
  ClientPrivKeyFile = #{relative(@droplet.sandbox + 'usr/safenet/lunaclient/cert/client/client-private-key.pem')};
  HtlDir            = #{relative(@droplet.sandbox + 'usr/safenet/lunaclient/htl')};
  ServerCAFile      = #{relative(@droplet.sandbox + 'usr/safenet/lunaclient/cert/server/server-certificates.pem')};
  SSLConfigFile     = #{relative(@droplet.sandbox + 'usr/safenet/lunaclient/bin/openssl.cnf')};

EOS
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
