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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling Azure Application Insights support.
    class AzureApplicationInsightsAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, CONNECTION_STRING, INSTRUMENTATION_KEY)['credentials']

        if credentials.key?(CONNECTION_STRING)
          @droplet.java_opts.add_system_property('applicationinsights.connection.string',
                                                 credentials[CONNECTION_STRING])
        end
        if credentials.key?(INSTRUMENTATION_KEY)
          @droplet.java_opts.add_system_property('APPLICATION_INSIGHTS_IKEY',
                                                 credentials[INSTRUMENTATION_KEY])
          # add environment variable for compatibility with agent version 3.x
          # this triggers a warning message to switch to connection string
          @droplet.environment_variables.add_environment_variable('APPINSIGHTS_INSTRUMENTATIONKEY',
                                                                  credentials[INSTRUMENTATION_KEY])
        end
        @droplet.java_opts.add_javaagent(@droplet.sandbox + jar_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service?(FILTER, CONNECTION_STRING, INSTRUMENTATION_KEY)
      end

      FILTER = /azure-application-insights/.freeze

      CONNECTION_STRING = 'connection_string'
      INSTRUMENTATION_KEY = 'instrumentation_key'

      private_constant :FILTER, :CONNECTION_STRING, :INSTRUMENTATION_KEY

    end

  end
end
