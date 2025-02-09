# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2024 the original author or authors.
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
require 'component_helper'
require 'java_buildpack/framework/instana_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::InstanaAgent do
  include_context 'with component help'

  it 'does not detect without instana service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/instana/, 'agentkey', 'endpointurl').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'agentkey' => 'test-akey',
                                                                              'endpointurl' => 'test-epurl' })

      allow(application_cache).to receive(:get)
        .with('https://_:test-akey@artifact-public.instana.io/artifactory/rel-generic-instana-virtual/com/instana/standalone-collector-jvm/%5BRELEASE%5D/standalone-collector-jvm-%5BRELEASE%5D.jar')
        .and_yield(Pathname.new('spec/fixtures/stub-instana-agent.jar').open, false)
    end

    it 'detects with instana service' do
      expect(component.detect).to eq('instana-agent=latest')
    end

    it 'downloads instana agent jar',
       cache_fixture: 'stub-instana-agent.jar' do

      component.compile
      expect(sandbox + 'instana_agent-latest.jar').to exist
    end

    it 'sets Java Agent with Instana Agent' do

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/instana_agent/instana_agent-latest.jar')
    end

    it 'updates environment variables' do

      component.release

      expect(environment_variables).to include('INSTANA_AGENT_KEY=test-akey')
      expect(environment_variables).to include('INSTANA_ENDPOINT_URL=test-epurl')
    end

  end

end
