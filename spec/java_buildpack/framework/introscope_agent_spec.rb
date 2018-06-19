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
require 'java_buildpack/framework/introscope_agent'

describe JavaBuildpack::Framework::IntroscopeAgent do
  include_context 'with component help'

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
      allow(services).to receive(:one_service?).with(/introscope/, %w[agent_manager_url url]).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with introscope-n/a service' do
      expect(component.detect).to eq("introscope-agent=#{version}")
    end

    it 'expands Introscope agent zip', cache_fixture: 'stub-introscope-agent.tar' do

      component.compile

      expect(sandbox + 'Agent.jar').to exist
    end

    context do
      let(:credentials) { { 'agent_name' => 'another-test-agent-name', 'url' => 'default-host:5001' } }

      it 'adds agent_name from credentials to JAVA_OPTS if specified' do
        component.release

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=another-test-agent-name')
      end
    end

    context do

      let(:credentials) { { 'url' => 'test-host-name:5001' } }

      it 'parses the url and sets host port and default socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=test-host-name:5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                       'com.wily.isengard.postofficehub.link.net.DefaultSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                     '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do

      let(:credentials) { { 'agent_manager_url' => 'test-host-name:5001' } }

      it 'parses the agent_manager_url and sets host port and default socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=test-host-name:5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5001')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                       'com.wily.isengard.postofficehub.link.net.DefaultSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                     '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'url' => 'ssl://test-host-name:5443' } }

      it 'parses the url and sets host, port, and ssl socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=ssl://test-host-name:5443')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5443')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.SSLSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'agent_manager_url' => 'ssl://test-host-name:5443' } }

      it 'parses the agent_manager_url and sets host, port, and ssl socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=ssl://test-host-name:5443')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=5443')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.SSLSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'url' => 'http://test-host-name:8081' } }

      it 'parses the url and sets host, port, and http socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=http://test-host-name:8081')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8081')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'agent_manager_url' => 'http://test-host-name:8081' } }

      it 'parses the agent_manager_url and sets host, port, and http socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=http://test-host-name:8081')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8081')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'url' => 'https://test-host-name:8444' } }

      it 'parses the url and sets host, port, and https socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=https://test-host-name:8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpsTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'agent_manager_url' => 'https://test-host-name:8444' } }

      it 'parses the agent_manager_url and sets host, port, and https socket factory' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=https://test-host-name:8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpsTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
      end
    end

    context do
      let(:credentials) { { 'url' => 'https://test-host-name:8444', 'credential' => 'test-credential-cccf-88-ae' } }

      it 'sets the url and also the credential' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=https://test-host-name:8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpsTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
        expect(java_opts).to include('-DagentManager.credential=test-credential-cccf-88-ae')
      end
    end

    context do
      let(:credentials) do
        { 'agent_manager_url'        => 'https://test-host-name:8444',
          'agent_manager_credential' => 'test-credential-cccf-88-ae' }
      end

      it 'sets the agent_manager_url and also the agent_manager_credential' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=test-application-name')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=https://test-host-name:8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpsTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
        expect(java_opts).to include('-DagentManager.credential=test-credential-cccf-88-ae')
      end
    end

    context do
      let(:credentials) do
        { 'agent_manager_url'        => 'https://test-host-name:8444',
          'agent_manager_credential' => 'test-credential-cccf-88-ae',
          'agent_default_process_name' => 'TestProcess' }
      end

      it 'sets the agent_manager_url, agent_manager_credential, and agent_process_name' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/introscope_agent/Agent.jar')
        expect(java_opts).to include('-Dcom.wily.introscope.agentProfile=$PWD/.java-buildpack/introscope_agent/core' \
                                     '/config/IntroscopeAgent.profile')
        expect(java_opts).to include('-Dintroscope.agent.defaultProcessName=TestProcess')
        expect(java_opts).to include('-Dintroscope.agent.hostName=test-application-uri-0')

        expect(java_opts).to include('-DagentManager.url.1=https://test-host-name:8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.host.DEFAULT=test-host-name')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.port.DEFAULT=8444')
        expect(java_opts).to include('-Dintroscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT=' \
                                     'com.wily.isengard.postofficehub.link.net.HttpsTunnelingSocketFactory')

        expect(java_opts).to include('-Dcom.wily.introscope.agent.agentName=$(expr "$VCAP_APPLICATION" : ' \
                                      '\'.*application_name[": ]*\\([A-Za-z0-9_-]*\\).*\')')
        expect(java_opts).to include('-DagentManager.credential=test-credential-cccf-88-ae')
      end
    end

  end
end
