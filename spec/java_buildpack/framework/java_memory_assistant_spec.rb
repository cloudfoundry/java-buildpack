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

require 'spec_helper'
require 'application_helper'
require 'component_helper'
require 'java_buildpack/framework/java_memory_assistant'
require 'java_buildpack/framework/java_memory_assistant/agent'
require 'java_buildpack/framework/java_memory_assistant/clean_up'
require 'java_buildpack/framework/java_memory_assistant/heap_dump_folder'

describe JavaBuildpack::Framework::JavaMemoryAssistant do
  include_context 'with component help'

  let(:component) { StubJavaMemoryAssistant.new context }

  context do

    let(:configuration) do
      {
        'enabled' => false
      }
    end

    it 'does not activate submodules if it is disabled in the configuration' do
      expect(component.detect).not_to be_truthy
    end

  end

  context do

    let(:configuration) do
      { 'enabled' => true,
        'agent' => agent_configuration,
        'clean_up' => clean_up_configuration }
    end

    let(:agent_configuration) { instance_double('agent_configuration') }

    let(:clean_up_configuration) { instance_double('clean_up_configuration') }

    it 'creates submodules' do
      allow(JavaBuildpack::Framework::JavaMemoryAssistantAgent)
        .to receive(:new).with(sub_configuration_context(agent_configuration))
      allow(JavaBuildpack::Framework::JavaMemoryAssistantHeapDumpFolder)
        .to receive(:new).with(sub_configuration_context(agent_configuration))
      allow(JavaBuildpack::Framework::JavaMemoryAssistantCleanUp)
        .to receive(:new).with(sub_configuration_context(clean_up_configuration))

      component.sub_components context
    end
  end

end

class StubJavaMemoryAssistant < JavaBuildpack::Framework::JavaMemoryAssistant

  public :command, :sub_components, :supports?

end
