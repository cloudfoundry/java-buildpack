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

require 'spec_helper'
require 'application_helper'
require 'component_helper'
require 'java_buildpack/framework/java_memory_assistant/clean_up'

describe JavaBuildpack::Framework::JavaMemoryAssistantCleanUp do
  include_context 'application_helper'
  include_context 'component_helper'

  let(:version) { '1.2.3' }

  context do

    let(:configuration) do
      {
        'max_dump_count' => 1
      }
    end

    it 'downloads and unpacks the cleanup command',
       cache_fixture: 'stub-java-memory-assistant-cleanup.zip' do

      component.compile

      expect(sandbox + 'cleanup').to exist
    end

  end

  context do

    let(:configuration) do
      {
        'max_dump_count' => 1
      }
    end

    it 'configures clean up' do
      component.release

      expect(java_opts).to include('-Djma.command.interpreter=')
      expect(java_opts).to include('-Djma.execute.before=$PWD/.java-buildpack/java_memory_assistant_clean_up/' \
        'cleanup')
    end

  end

  context do

    let(:configuration) do
      {
        'max_dump_count' => 0
      }
    end

    it 'does not configure clean up when max_dump_count is zero' do
      component.release

      expect(java_opts).not_to include('-Djma.command.interpreter=')
      expect(java_opts).not_to include('-Djma.execute.before=$PWD/.java-buildpack/java_memory_assistant_clean_up/' \
        'cleanup')
    end

  end

  context do

    let(:configuration) do
      {}
    end

    it 'does not configure clean up when max_dump_count is not set' do
      component.release

      expect(java_opts).not_to include('-Djma.command.interpreter=')
      expect(java_opts).not_to include('-Djma.execute.before=$PWD/.java-buildpack/java_memory_assistant_clean_up/' \
        'cleanup')
    end

  end

end
