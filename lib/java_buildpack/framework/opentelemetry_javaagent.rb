# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2023 the original author or authors.
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

    # Main class for adding the OpenTelemetry Javaagent instrumentation
    class OpenTelemetryJavaagent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        java_opts = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + jar_name)

        # Set the otel.service.name to the application_name
        app_name = @application.details['application_name']
        java_opts.add_system_property('otel.service.name', app_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? REQUIRED_SERVICE_NAME_FILTER
      end

      # bound service must contain the string `otel-collector`
      REQUIRED_SERVICE_NAME_FILTER = /otel-collector/.freeze

    end
  end
end
