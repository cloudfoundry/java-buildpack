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
require 'java_buildpack/component/droplet'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the integraton of the JavaMemoryAssistant to set up clean up of dumps.
    class JavaMemoryAssistantCleanUp < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        download_zip false
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless supports?

        @droplet.environment_variables
                .add_environment_variable 'JMA_MAX_DUMP_COUNT', @configuration['max_dump_count'].to_s

        @droplet.java_opts
                .add_system_property('jma.command.interpreter', '')
                .add_system_property('jma.execute.before', @droplet.sandbox + 'cleanup')
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['max_dump_count'].to_i.positive?
      end

    end
  end
end
