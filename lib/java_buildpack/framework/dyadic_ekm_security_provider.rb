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

    # Encapsulates the functionality for enabling zero-touch Dyadic EKM Java Security Provider support.
    class DyadicEkmSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        setup_ext_dir

        @droplet.copy_resources
        @droplet.security_providers << 'com.dyadicsec.provider.DYCryptoProvider'
        @droplet.additional_libraries << dyadic_jar if @droplet.java_home.java_9_or_later?

        credentials = @application.services.find_service(FILTER, 'ca', 'key', 'recv_timeout', 'retries', 'send_timeout',
                                                         'servers')['credentials']
        write_files(credentials)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables
                .add_environment_variable 'LD_LIBRARY_PATH', @droplet.sandbox + 'usr/lib'

        if @droplet.java_home.java_9_or_later?
          @droplet.additional_libraries << dyadic_jar
        else
          @droplet.extension_directories << ext_dir
        end
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'ca', 'key', 'recv_timeout', 'retries', 'send_timeout', 'servers'
      end

      private

      FILTER = /dyadic/

      private_constant :FILTER

      def cert_file
        @droplet.sandbox + 'etc/dsm/ca.crt'
      end

      def conf_file
        @droplet.sandbox + 'etc/dsm/client.conf'
      end

      def dyadic_jar
        @droplet.sandbox + 'usr/lib/dsm/dsm-advapi-1.0.jar'
      end

      def ext_dir
        @droplet.sandbox + 'ext'
      end

      def key_file
        @droplet.sandbox + 'etc/dsm/key.pem'
      end

      def setup_ext_dir
        FileUtils.mkdir ext_dir
        FileUtils.ln_s dyadic_jar.relative_path_from(ext_dir), ext_dir, force: true
      end

      def write_cert(cert)
        FileUtils.mkdir_p cert_file.parent
        cert_file.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{cert}\n"
        end
      end

      def write_conf(servers, send_timeout, recv_timeout, retries)
        FileUtils.mkdir_p conf_file.parent
        conf_file.open(File::CREAT | File::WRONLY) do |f|
          f.write <<~CONFIG
            servers         = #{servers}
            send_timeout    = #{send_timeout}
            recv_timeout    = #{recv_timeout}
            retries         = #{retries}
            ha_mode_standby = 1
CONFIG
        end
      end

      def write_files(credentials)
        write_key credentials['key']
        write_cert credentials['ca']
        write_conf credentials['servers'], credentials['send_timeout'], credentials['recv_timeout'],
                   credentials['retries']
      end

      def write_key(key)
        FileUtils.mkdir_p key_file.parent
        key_file.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{key}\n"
        end
      end

    end
  end
end
