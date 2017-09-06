# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

    # Support hotswap agent (http://hotswapagent.org/)
    class HotswapAgent < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'Hotswap Agent'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_agentpath(@droplet.sandbox + ('lib/hotswap-agent.jar'))
     end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        enabled? && environment_variables['HOT_SWAP_AGENT'] == 'true'
      end

      private

      def enabled?
        @configuration['enabled'].nil? || @configuration['enabled']
      end

    end

  end
end
