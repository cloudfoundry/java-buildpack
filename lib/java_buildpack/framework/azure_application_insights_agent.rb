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
        credentials = @application.services.find_service(FILTER, INSTRUMENTATION_KEY)['credentials']

        @droplet
          .java_opts.add_javaagent(@droplet.sandbox + jar_name)
          .add_system_property('APPLICATION_INSIGHTS_IKEY', credentials[INSTRUMENTATION_KEY])
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, INSTRUMENTATION_KEY
      end

      FILTER = /azure-application-insights/.freeze

      INSTRUMENTATION_KEY = 'instrumentation_key'

      private_constant :FILTER, :INSTRUMENTATION_KEY

    end

  end
end
