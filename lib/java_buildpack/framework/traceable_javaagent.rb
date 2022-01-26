# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2022 the original author or authors.
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

    # Encapsulates the functionality for enabling the Traceable Java Agent
    class TraceableJavaagent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger TraceableJavaagent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        java_opts = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + jar_name)

        if @application.environment.key?('HT_SERVICE_NAME') ||
          java_opts.any? { |java_opt| java_opt =~ /ht.service.name/ }
          return
        end

        app_name = @configuration['default_application_name'] || @application.details['application_name']
        java_opts.add_system_property('ht.service.name', "\\\"#{app_name}\\\"")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        java_opts = @droplet.java_opts
        reporting_endpoint_specified = (@application.environment.key?('HT_REPORTING_ENDPOINT') &&
        !@application.environment['HT_REPORTING_ENDPOINT'].empty?) ||
          java_opts.any? { |java_opt| java_opt =~ /ht.reporting.endpoint/ }
        opa_endpoint_specified = (@application.environment.key?('TA_OPA_ENDPOINT') &&
        !@application.environment['TA_OPA_ENDPOINT'].empty?) ||
          java_opts.any? { |java_opt| java_opt =~ /ta.reporting.endpoint/ }
        reporting_endpoint_specified && opa_endpoint_specified
      end
    end
  end
end
