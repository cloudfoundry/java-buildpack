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

  context do
    it 'does not support riverbed-appinternals-agent service' do
      expect(component.supports?).to be false
    end

    it 'should not detect with riverbed-appinternals-agent service' do
      expect(component.detect).to eq(nil)
    end
  end

  context do
    let(:vcap_services) do
      { 'test-service-n/a' => [{ 'name'        => 'appinternals_test_service', 'label' => 'test-service-n/a',
                                 'tags'        => ['test-service-tag'], 'plan' => 'test-plan',
                                 'credentials' => { 'uri' => 'test-uri' } }] }
    end
    it 'supports riverbed-appinternals-agent service' do
      expect(component.supports?).to be true
    end

    it 'detects with riverbed-appinternals-agent service' do
      expect(component.detect).to eq("riverbed-appinternals-agent=#{version}")
    end
    context do
      it 'unzip riverbed appinternals agent zip file' ,
         cache_fixture: 'stub-riverbed-appinternals-agent.zip' do

        component.compile

        expect(sandbox + 'agent/lib/libAwProfile64.so').to exist
        expect(sandbox + 'agent/lib/libAwProfile.so').to exist
        expect(sandbox + 'agent/lib/librpilj.so').to exist
        expect(sandbox + 'agent/lib/librpilj64.so').to exist
        expect(sandbox + 'agent/lib/awcore/JIDAcore.jar').to exist
        expect(sandbox + 'agent/lib/awcore/JidaSecurity.policy').to exist
        expect(sandbox + 'agent/lib/awapp/JIDAapp.jar').to exist
        expect(sandbox + 'agent/lib/awapp/JIDAutil.jar').to exist
        expect(sandbox + 'agent/classes').to exist
      end
    end
  end

  context do

    before do
      allow(component).to receive(:architecture).and_return('x86_64')
    end
    context do
      before do
        allow(services).to receive(:find_service).and_return('credentials' => {})
        allow(component).to receive(:version).and_return('10.15.1_BL234')
      end
      it 'sets default values to java opts' do
        component.release
        expect(environment_variables).to include('DSA_PORT=2111')
        expect(environment_variables).to include('RVBD_AGENT_PORT=7073')
        expect(environment_variables).to include('AIX_INSTRUMENT_ALL=1')
        expect(environment_variables).to include('RVBD_AGENT_FILES=1')
        expect(environment_variables).to include('RVBD_JBP_VERSION=10.15.1_BL234')
        expect(java_opts).to include("-agentpath:$PWD/.java-buildpack/riverbed_appinternals_agent/agent/lib/librpilj64.so")
      end
    end

    context do
      before do
        allow(services).to receive(:find_service).and_return('credentials' => {'rvbd_dsa_port'=>'10000','rvbd_agent_port'=>'20000', 'rvbd_moniker'=>'special_name'})
      end
      it 'sets customized values to java opts' do
        component.release
        expect(environment_variables).to include('DSA_PORT=10000')
        expect(environment_variables).to include('RVBD_AGENT_PORT=20000')
        expect(java_opts).to include("-Driverbed.moniker=special_name")
      end
    end
  end


end