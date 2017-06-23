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
require 'component_helper'
require 'java_buildpack/framework/introscope_agent'

describe JavaBuildpack::Framework::IntroscopeAgent do
  include_context 'component_helper'

  let(:configuration) do
    { 'default_agent_name' => "$(expr \"$VCAP_APPLICATION\" : '.*application_name[\": ]*\\([A-Za-z0-9_-]*\\).*')" }
  end

  let(:vcap_application) do
    { 'application_name' => 'test-application-name',
      'application_uris' => %w[test-application-uri-0 test-application-uri-1] }
  end

  it 'does not detect without introscope-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/introscope/, 'host-name').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with introscope-n/a service' do
      expect(component.detect).to eq("introscope-agent=#{version}")
    end

    it 'expands Introscope agent zip',
       cache_fixture: 'stub-introscope-agent.tar' do

      component.compile

      expect(sandbox + 'Agent.jar').to exist
    end

    context do

      let(:credentials) { { 'host-name' => 'test-host-name' } }

      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-DagentManager.url.1=http://test-host-name')
        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                     '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end

      context do
        let(:credentials) { super().merge 'agent-name' => 'another-test-agent-name' }

        it 'adds agent-name from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=another-test-agent-name')
        end
      end

      context do
        let(:credentials) { super().merge 'port' => 'test-port' }

        it 'adds port from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=test-port')
          expect(java_opts).to include('-DagentManager.url.1=http://test-host-name:test-port')
        end
      end

      context do
        let(:credentials) { super().merge 'ssl' => 'true' }

        it 'adds ssl socket factory from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                       'com.wily.isengard.postofficehub.link.net.SSLSocketFactory')
          expect(java_opts).to include('-DagentManager.url.1=https://test-host-name')
        end
      end
    end

  end

end
