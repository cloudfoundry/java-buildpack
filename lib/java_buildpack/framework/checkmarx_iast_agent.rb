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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running with Checkmarx IAST Agent
    class CheckmarxIastAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
      # instance variables are exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      def initialize(context)
        @application = context[:application]
        @component_name = self.class.to_s.space_case
        @configuration = context[:configuration]
        @droplet = context[:droplet]

        if supports?
          @version = ''
          @uri = @application.services.find_service(FILTER, 'server')['credentials']['server'].chomp +
                 '/iast/compilation/download/JAVA'
        end

        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger CheckmarxIastAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Checkmarx IAST download location is always accessible'
        ) do
          download_zip(false)
        end

        # Disable cache (no point, when running in a container)
        File.open(@droplet.sandbox + 'cx_agent.override.properties', 'a') do |f|
          f.write("\nenableWeavedClassCache=false\n")
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        # Default cxAppTag to application name if not set as an env var
        app_tag = ENV.fetch('cxAppTag', nil) || application_name
        # Default team to CxServer if not set as env var
        team = ENV.fetch('cxTeam', nil) || 'CxServer'

        @droplet.java_opts
                .add_javaagent(@droplet.sandbox + 'cx-launcher.jar')
                .add_preformatted_options('-Xverify:none')
                .add_system_property('cx.logToConsole', 'true')
                .add_system_property('cx.appName', application_name)
                .add_system_property('cxAppTag', app_tag)
                .add_system_property('cxTeam', team)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.find_service(FILTER, 'server')
      end

      private

      FILTER = /^checkmarx-iast$/.freeze

      private_constant :FILTER

      def application_name
        @application.details['application_name'] || 'ROOT'
      end

    end

  end

end
