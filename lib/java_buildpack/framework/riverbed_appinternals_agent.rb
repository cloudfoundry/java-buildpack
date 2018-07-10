# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

    # Encapsulates the functionality for running the Riverbed Appinternals Agent support.
    class RiverbedAppinternalsAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip(false, @droplet.sandbox, @component_name)
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']

        @droplet.environment_variables
                .add_environment_variable('AIX_INSTRUMENT_ALL', 1)
                .add_environment_variable('DSA_PORT', dsa_port(credentials))
                .add_environment_variable('RVBD_AGENT_FILES', 1)
                .add_environment_variable('RVBD_AGENT_PORT', agent_port(credentials))
                .add_environment_variable('RVBD_JBP_VERSION', @version)

        @droplet.java_opts.add_agentpath(agent_path)

        return unless rvbd_moniker(credentials)
        @droplet.java_opts.add_system_property('riverbed.moniker', rvbd_moniker(credentials))
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service?(FILTER)
      end

      private

      FILTER = /appinternals/

      private_constant :FILTER

      def agent_path
        @droplet.sandbox + 'agent/lib' + lib_name
      end

      def agent_port(credentials)
        credentials['rvbd_agent_port'] || 7073
      end

      def architecture
        `uname -m`.strip
      end

      def dsa_port(credentials)
        credentials['rvbd_dsa_port'] || 2111
      end

      def lib_name
        %w[x86_64 i686].include?(architecture) ? 'librpilj64.so' : 'librpilj.so'
      end

      def rvbd_moniker(credentials)
        credentials['rvbd_moniker'] || @configuration['rvbd_moniker']
      end
    end
  end
end
