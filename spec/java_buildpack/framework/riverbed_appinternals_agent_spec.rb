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

require 'spec_helper'
require 'component_helper'
require 'java_buildpack/framework/riverbed_appinternals_agent'

describe JavaBuildpack::Framework::RiverbedAppinternalsAgent do
  include_context 'with component help'

  it 'does detect riverbed-appinternals-agent service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/appinternals/).and_return(true)
    end

    it 'detects with riverbed-appinternals-agent service' do
      expect(component.detect).to eq("riverbed-appinternals-agent=#{version}")
    end

    it 'unzips riverbed appinternals agent zip file',
       cache_fixture: 'stub-riverbed-appinternals-agent.zip' do

      component.compile

      expect(sandbox + 'agent/lib/librpilj64.so').to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => {})

      component.release

      expect(environment_variables).to include('AIX_INSTRUMENT_ALL=1')
      expect(environment_variables).to include('DSA_PORT=2111')
      expect(environment_variables).to include('RVBD_AGENT_FILES=1')
      expect(environment_variables).to include('RVBD_AGENT_PORT=7073')
      expect(environment_variables).to include('RVBD_JBP_VERSION=0.0.0')

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/riverbed_appinternals_agent/agent/lib/' \
                                   'librpilj64.so')
    end

    it 'updates JAVA_OPTS with credentials' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'rvbd_dsa_port' => '10000', \
                                                                              'rvbd_agent_port' => '20000', \
                                                                              'rvbd_moniker' => 'special_name' })

      component.release

      expect(environment_variables).to include('DSA_PORT=10000')
      expect(environment_variables).to include('RVBD_AGENT_PORT=20000')
      expect(java_opts).to include('-Driverbed.moniker=special_name')
    end
  end
end
