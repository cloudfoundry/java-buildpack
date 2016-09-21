# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/format_duration'
require 'fileutils'
require 'shellwords'
require 'tempfile'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing container-based certificates to an application.
    class ContainerCertificateTrustStore < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger ContainerCertificateTrustStore
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports_configuration? && supports_file? ? id(certificates.length) : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts '-----> Creating TrustStore with container certificates'

        resolved_certificates = certificates
        with_timing(caption(resolved_certificates)) do
          FileUtils.mkdir_p trust_store.parent
          resolved_certificates.each_with_index { |certificate, index| add_certificate certificate, index }
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('javax.net.ssl.trustStore', trust_store)
          .add_system_property('javax.net.ssl.trustStorePassword', password)
      end

      private

      CA_CERTIFICATES = Pathname.new('/etc/ssl/certs/ca-certificates.crt').freeze

      private_constant :CA_CERTIFICATES

      def add_certificate(certificate, index)
        @logger.debug { "Adding certificate\n#{certificate}" }

        file = write_certificate certificate
        shell "#{keytool} -importcert -noprompt -keystore #{trust_store} -storepass #{password} " \
              "-file #{file.to_path} -alias certificate-#{index}"
      end

      def ca_certificates
        CA_CERTIFICATES
      end

      def caption(resolved_certificates)
        "Adding #{resolved_certificates.count} certificates to #{trust_store.relative_path_from(@droplet.root)}"
      end

      def certificates
        certificates = []

        certificate = nil
        ca_certificates.each_line do |line|
          if line =~ /BEGIN CERTIFICATE/
            certificate = line
          elsif line =~ /END CERTIFICATE/
            certificate += line
            certificates << certificate
            certificate = nil
          elsif !certificate.nil?
            certificate += line
          end
        end

        certificates
      end

      def id(count)
        "#{self.class.to_s.dash_case}=#{count}"
      end

      def keytool
        @droplet.java_home.root + 'bin/keytool'
      end

      def password
        'java-buildpack-trust-store-password'
      end

      def supports_configuration?
        @configuration['enabled']
      end

      def supports_file?
        ca_certificates.exist?
      end

      def trust_store
        @droplet.sandbox + 'truststore.jks'
      end

      def write_certificate(certificate)
        file = Tempfile.new('certificate-')
        file.write(certificate)
        file.fsync
        file
      end

    end

  end
end
