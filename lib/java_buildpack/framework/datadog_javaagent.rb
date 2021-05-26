# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2021 the original author or authors.
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

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Elastic APM support.
    class DatadogJavaagent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context)
        super(context)
        @datadog_buildpack = File.exist? File.join(@droplet.root, 'datadog')
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger DatadogJavaagent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @logger.error 'Datadog Buildpack is required, but not found' unless @datadog_buildpack

        download_jar if @datadog_buildpack
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless @datadog_buildpack

        java_opts = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + jar_name)

        unless @application.environment.key?('DD_SERVICE')
          app_name = @configuration['default_application_name'] || @application.details['application_name']
          java_opts.add_system_property('dd.service', "\\\"#{app_name}\\\"")
        end

        version = @application.environment['DD_VERSION'] || @configuration['default_application_version'] ||
          @application.details['application_version']
        java_opts.add_system_property('dd.version', version)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        api_key_defined = @application.environment.key?('DD_API_KEY') && !@application.environment['DD_API_KEY'].empty?
        apm_disabled = @application.environment['DD_APM_ENABLED'] == 'false'
        (api_key_defined && !apm_disabled)
      end
    end
  end
end
