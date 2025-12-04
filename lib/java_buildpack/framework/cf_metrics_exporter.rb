# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2025 the original author or authors.
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
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack
  module Framework

    # Adds the cf-metrics-exporter javaagent so that Cloud Foundry runtime metrics can be exported.
    #
    # Enable via application manifest/environment:
    #   CF_METRICS_EXPORTER_ENABLED: "true"
    #
    # Configure agent options via:
    #   CF_METRICS_EXPORTER_PROPS: "rawAgentArgString" (passed verbatim after '=')
    #
    # The artifact location and version can be controlled via config/cf_metrics_exporter.yml
    class CfMetricsExporter < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        version = JavaBuildpack::Util::TokenizedVersion.new(@configuration['version'] || DEFAULT_VERSION)
        uri     = @configuration['uri'] || DEFAULT_URI

        # Use a deterministic jar name in the sandbox
        download_jar(version, uri, jar_name(version))
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless supports?

        java_opts = @droplet.java_opts
        version   = JavaBuildpack::Util::TokenizedVersion.new(@configuration['version'] || DEFAULT_VERSION)
        agent_jar = @droplet.sandbox + jar_name(version)

        props_env = @application.environment['CF_METRICS_EXPORTER_PROPS']

        if props_env && !props_env.empty?
          # Pass the string verbatim so users can copy/paste from and to -javaagent command line
          java_opts.add_preformatted_options "-javaagent:#{agent_jar.relative_path_from(@droplet.root)}=#{props_env}"
        else
          java_opts.add_javaagent(agent_jar)
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? "cf-metrics-exporter=#{@configuration['version'] || DEFAULT_VERSION}" : nil
      end

      def supports?
        enabled = @application.environment['CF_METRICS_EXPORTER_ENABLED']
        enabled&.downcase == 'true'
      end

      private

      DEFAULT_VERSION = '0.7.1'
      DEFAULT_URI     = 'https://github.com/rabobank/cf-metrics-exporter/releases/download/0.7.1/cf-metrics-exporter-0.7.1.jar'

      def jar_name(version)
        "cf-metrics-exporter-#{version}.jar"
      end

    end
  end
end
