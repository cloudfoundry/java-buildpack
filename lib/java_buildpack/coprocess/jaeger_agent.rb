# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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
require 'java_buildpack/coprocess'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/play/factory'
require 'fileutils'
module JavaBuildpack
  module Coprocess

    # Encapsulates the detect, compile, and release functionality for Play applications.
    class JaegerAgent < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger JaegerAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        enabled? ? "#{self.class.to_s.dash_case}=#{version}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jaeger
        generate_files
        FileUtils.rm_rf(@droplet.sandbox)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        [
          '($PWD/jaeger/jaeger-agent',
          '--reporter.grpc.tls=true',
          '--reporter.grpc.tls.ca=$PWD/jaeger/ca_cert.crt',
          '--reporter.grpc.tls.cert=$PWD/jaeger/tls_cert.crt',
          '--reporter.grpc.tls.key=$PWD/jaeger/tls_key.key',
          '--reporter.grpc.host-port=' + credentials['jaeger-collector-url'],
          additional_arguements,
          '&)'
        ].flatten.compact.join(' ')
      end

      protected

      def enabled?
        @application.services.one_service? FILTER, APIURL, TLS_CA, TLS_CERT, TLS_KEY
      end

      private

      APIURL = 'jaeger-collector-url'
      TLS_CA = 'tls_ca'
      TLS_CERT = 'tls_cert'
      TLS_KEY = 'tls_key'

      FILTER = /jaeger/.freeze

      private_constant :APIURL, :TLS_CA, :TLS_CERT, :TLS_KEY, :FILTER

      def credentials
        @application.services.find_service(FILTER, APIURL, TLS_CA, TLS_CERT, TLS_KEY)['credentials']
      end

      def version
        @configuration['version']
      end

      def repo
        @configuration['repository_root']
      end

      def download_jaeger
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Jaeger Agent download location is always accessible'
        ) do
          download_tar(version, "#{repo}/v#{version}/jaeger-#{version}-linux-amd64.tar.gz")
          FileUtils.mkdir(@droplet.root + 'jaeger')
          FileUtils.cp_r(@droplet.sandbox + 'jaeger-agent', @droplet.root + 'jaeger')
        end
      end

      def generate_files
        ca_file = File.new(@droplet.root + 'jaeger' + 'ca_cert.crt', 'w')
        ca_file.puts(credentials['tls_ca'])
        tls_cert = File.new(@droplet.root + 'jaeger' + 'tls_cert.crt', 'w')
        tls_cert.puts(credentials['tls_cert'])
        tls_key = File.new(@droplet.root + 'jaeger' + 'tls_key.key', 'w')
        tls_key.puts(credentials['tls_key'])
      end

      def additional_arguements
        ENV['JAEGER_ADDITIONAL_ARGUEMENTS']
      end
    end
  end
end
