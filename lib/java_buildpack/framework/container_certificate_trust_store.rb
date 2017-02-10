# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'fileutils'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing container-based certificates to an application.
    class ContainerCertificateTrustStore < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar

        with_timing("Adding certificates to #{trust_store.relative_path_from(@droplet.root)}") do
          FileUtils.mkdir_p trust_store.parent

          shell "#{java} -jar #{@droplet.sandbox + jar_name} --container-source #{ca_certificates} --destination " \
                "#{trust_store} --destination-password #{password} --jre-source #{cacerts} --jre-source-password " \
                'changeit'
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('javax.net.ssl.trustStore', trust_store)
          .add_system_property('javax.net.ssl.trustStorePassword', password)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        supports_configuration? && supports_file?
      end

      private

      DARWIN_CERTIFICATES = Pathname.new('/etc/ssl/cert.pem').freeze

      UNIX_CERTIFICATES = Pathname.new('/etc/ssl/certs/ca-certificates.crt').freeze

      private_constant :DARWIN_CERTIFICATES, :UNIX_CERTIFICATES

      def ca_certificates
        if `uname -s` =~ /Darwin/
          DARWIN_CERTIFICATES
        else
          UNIX_CERTIFICATES
        end
      end

      def cacerts
        @droplet.java_home.root + 'lib/security/cacerts'
      end

      def java
        @droplet.java_home.root + 'bin/java'
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

    end

  end
end
