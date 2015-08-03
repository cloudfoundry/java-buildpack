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
        write_host_certificate credentials
        write_client_certificate credentials
        write_client_private_key credentials
        write_host credentials
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
        @application.services.one_service? FILTER, 'host', 'host-certificate', 'client-private-key',
                                           'client-certificate'
      end

      private

      FILTER = /luna/.freeze

      private_constant :FILTER

      def chrystoki
        @droplet.sandbox + 'Chrystoki.conf'
      end

      def client_certificate
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameCert.pem'
      end

      def client_private_key
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameKey.pem'
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

      def host_certificate
        @droplet.sandbox + 'usr/safenet/lunaclient/cert/server/CAFile.pem'
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

      def rpm2cpio
        Pathname.new(File.expand_path('../rpm2cpio.py', __FILE__))
      end

      def write_client_certificate(credentials)
        FileUtils.mkdir_p client_certificate.parent
        client_certificate.open(File::CREAT | File::WRONLY) { |f| f.write credentials['client-certificate'] }
      end

      def write_client_private_key(credentials)
        FileUtils.mkdir_p client_private_key.parent
        client_private_key.open(File::CREAT | File::WRONLY) { |f| f.write credentials['client-private-key'] }
      end

      def write_host_certificate(credentials)
        FileUtils.mkdir_p host_certificate.parent
        host_certificate.open(File::CREAT | File::WRONLY) { |f| f.write credentials['host-certificate'] }
      end

      def write_host(credentials)
        content = chrystoki.open(File::RDONLY) { |f| f.read }
        content.gsub!(/@@HOST@@/, credentials['host'])

        chrystoki.open(File::CREAT | File::WRONLY) do |f|
          f.truncate 0
          f.write content
          f.sync
        end
      end

    end

  end
end
