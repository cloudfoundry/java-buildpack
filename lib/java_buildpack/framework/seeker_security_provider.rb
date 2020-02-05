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

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Seeker support.
    class SeekerSecurityProvider < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)

        @uri = download_url(credentials) if supports?
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @uri ? self.class.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'Downloading from Synopsys Seeker Server'
        ) do
          download_zip('', @uri, false, @droplet.sandbox, @component_name)
        end
        @droplet.copy_resources
      rescue StandardError => e
        raise "Synopsys Seeker download failed: #{e}"
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        c = credentials

        @droplet.java_opts.add_javaagent(@droplet.sandbox + 'seeker-agent.jar')
        @droplet.environment_variables
                .add_environment_variable('SEEKER_SERVER_URL', c[SEEKER_SERVER_URL_CONFIG_KEY])
      end

      private

      # Relative path of the agent zip
      AGENT_PATH = '/rest/api/latest/installers/agents/binaries/JAVA'

      # seeker service name identifier
      FILTER = /seeker/i.freeze

      # JSON key for the address of seeker sensor
      SEEKER_SERVER_URL_CONFIG_KEY = 'seeker_server_url'

      private_constant :AGENT_PATH, :FILTER, :SEEKER_SERVER_URL_CONFIG_KEY

      def credentials
        @application.services.find_service(FILTER, SEEKER_SERVER_URL_CONFIG_KEY)['credentials']
      end

      def download_url(credentials)
        "#{credentials[SEEKER_SERVER_URL_CONFIG_KEY]}#{AGENT_PATH}"
      end

      def supports?
        @application.services.one_service?(FILTER, SEEKER_SERVER_URL_CONFIG_KEY)
      end

    end

  end

end
