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

require 'java_buildpack/component/modular_component'
require 'java_buildpack/framework'
require 'java_buildpack/framework/java_memory_assistant/agent'
require 'java_buildpack/framework/java_memory_assistant/clean_up'
require 'java_buildpack/framework/java_memory_assistant/heap_dump_folder'

module JavaBuildpack
  module Framework

    # Encapsulates the integraton of the JavaMemoryAssistant.
    class JavaMemoryAssistant < JavaBuildpack::Component::ModularComponent

      protected

      # (see JavaBuildpack::Component::ModularComponent#command)
      def command; end

      # (see JavaBuildpack::Component::ModularComponent#sub_components)
      def sub_components(context)
        [
          JavaMemoryAssistantAgent.new(sub_configuration_context(context, 'agent')),
          JavaMemoryAssistantHeapDumpFolder.new(sub_configuration_context(context, 'agent')),
          JavaMemoryAssistantCleanUp.new(sub_configuration_context(context, 'clean_up'))
        ]
      end

      # (see JavaBuildpack::Component::ModularComponent#supports?)
      def supports?
        @configuration['enabled']
      end

    end
  end
end
