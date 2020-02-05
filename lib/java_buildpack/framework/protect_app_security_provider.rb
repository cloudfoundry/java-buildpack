# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'shellwords'
require 'tempfile'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Safenet ProtectApp Java Security Provider support.
    class ProtectAppSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip false

        @droplet.copy_resources
        @droplet.security_providers << 'com.ingrian.security.nae.IngrianProvider'
        @droplet.additional_libraries << protect_app_jar if @droplet.java_home.java_9_or_later?

        credentials = @application.services.find_service(FILTER, 'client', 'trusted_certificates')['credentials']

        pkcs12 = merge_client_credentials credentials['client']
        add_client_credentials pkcs12

        add_trusted_certificates credentials['trusted_certificates']
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        if @droplet.java_home.java_9_or_later?
          @droplet.additional_libraries << protect_app_jar
        else
          @droplet.extension_directories << ext_dir
        end

        credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts

        java_opts
          .add_system_property('com.ingrian.security.nae.IngrianNAE_Properties_Conf_Filename',
                               @droplet.sandbox + 'IngrianNAE.properties')
          .add_system_property('com.ingrian.security.nae.Key_Store_Location', keystore)
          .add_system_property('com.ingrian.security.nae.Key_Store_Password', password)

        add_additional_properties(credentials, java_opts)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'client', 'trusted_certificates'
      end

      private

      FILTER = /protectapp/.freeze

      private_constant :FILTER

      def add_additional_properties(credentials, java_opts)
        credentials
          .reject { |key, _| key =~ /^client$/ || key =~ /^trusted_certificates$/ }
          .each { |key, value| java_opts.add_system_property("com.ingrian.security.nae.#{key}", value) }
      end

      def add_client_credentials(pkcs12)
        shell "#{keytool} -importkeystore -noprompt -destkeystore #{keystore} -deststorepass #{password} " \
              "-srckeystore #{pkcs12.path} -srcstorepass #{password} -srcstoretype pkcs12" \
              " -alias #{File.basename(pkcs12)}"
      end

      def add_trusted_certificates(trusted_certificates)
        trusted_certificates.each do |certificate|
          pem = write_certificate certificate

          shell "#{keytool} -importcert -noprompt -keystore #{keystore} -storepass #{password} " \
                "-file #{pem.path} -alias #{File.basename(pem)}"
        end
      end

      def ext_dir
        @droplet.sandbox + 'ext'
      end

      def keystore
        @droplet.sandbox + 'nae-keystore.jks'
      end

      def keytool
        @droplet.java_home.root + 'bin/keytool'
      end

      def merge_client_credentials(credentials)
        certificate = write_certificate credentials['certificate']
        private_key = write_private_key credentials['private_key']

        pkcs12 = Tempfile.new('pkcs12-')
        pkcs12.close

        shell "openssl pkcs12 -export -in #{certificate.path} -inkey #{private_key.path} " \
              "-name #{File.basename(pkcs12)} -out #{pkcs12.path} -passout pass:#{password}"

        pkcs12
      end

      def password
        'nae-keystore-password'
      end

      def protect_app_jar
        ext_dir + "IngrianNAE-#{@version}.000.jar"
      end

      def write_certificate(certificate)
        Tempfile.open('certificate-') do |f|
          f.write "#{certificate}\n"
          f.sync
          f
        end
      end

      def write_private_key(private_key)
        Tempfile.open('private-key-') do |f|
          f.write "#{private_key}\n"
          f.sync
          f
        end
      end

    end
  end
end
