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
require 'component_helper'
require 'java_buildpack/framework/app_dynamics_agent'

describe JavaBuildpack::Framework::AppDynamicsAgent do
  include_context 'with component help'

  let(:configuration) do
    { 'default_tier_name' => nil,
      'default_node_name' => "$(expr \"$VCAP_APPLICATION\" : '.*instance_index[\": ]*\\([[:digit:]]*\\).*')",
      'default_application_name' => nil }
  end

  it 'does not detect without app-dynamics-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/app-?dynamics/, 'host-name').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with app-dynamics-n/a service' do
      expect(component.detect).to eq("app-dynamics-agent=#{version}")
    end

    it 'expands AppDynamics agent zip',
       cache_fixture: 'stub-app-dynamics-agent.zip' do

      component.compile

      expect(sandbox + 'javaagent.jar').to exist
    end

    it 'raises error if host-name not specified' do
      expect { component.release }.to raise_error(/'host-name' credential must be set/)
    end

    context do

      let(:credentials) { { 'host-name' => 'test-host-name' } }

      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/app_dynamics_agent/javaagent.jar')
        expect(java_opts).to include('-Dappdynamics.controller.hostName=test-host-name')
        expect(java_opts).to include('-Dappdynamics.agent.applicationName=test-application-name')
        expect(java_opts).to include('-Dappdynamics.agent.tierName=test-application-name')
        expect(java_opts).to include('-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : ' \
                                     '\'.*instance_index[": ]*\\([[:digit:]]*\\).*\')')
      end

      context do
        let(:credentials) { super().merge 'tier-name' => 'another-test-tier-name' }

        it 'adds tier_name from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.tierName=another-test-tier-name')
        end
      end

      context do
        let(:credentials) { super().merge 'tier-name' => 'another-test tier-name' }

        it 'adds tier_name from credentials with space in name to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.tierName=another-test\ tier-name')
        end
      end

      context do
        let(:credentials) { super().merge 'tier-name' => '--> ${SOME_VAR} <--' }

        it 'adds tier_name from credentials with shell variable in it to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.tierName=\"--> ${SOME_VAR} <--\"')
        end
      end

      context do
        let(:credentials) { super().merge 'tier-name' => '$(echo \'Hello World!\') and stuff' }

        it 'adds tier_name from credentials with subshell in it to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.tierName=\"$(echo \'Hello World!\') and stuff\"')
        end
      end

      context do
        let(:credentials) { super().merge 'application-name' => 'another-test application-name' }

        it 'adds application_name from credentials with space in name to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.applicationName=another-test\ application-name')
        end
      end

      context do
        let(:credentials) { super().merge 'application-name' => '$(echo \'Hello World!\') and stuff' }

        it 'adds application_name from credentials with subshell in value to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.applicationName=\"$(echo \'Hello World!\') and stuff\"')
        end
      end

      context do
        let(:credentials) { super().merge 'application-name' => 'Name ${MY_APP_NAME}' }

        it 'adds application_name from credentials with env variable in value to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.applicationName=\"Name ${MY_APP_NAME}\"')
        end
      end

      context do
        let(:configuration) do
          { 'default_tier_name' => nil,
            'default_node_name' => nil,
            'default_application_name' => 'default application-name' }
        end

        it 'adds application_name from default config to JAVA_OPTS if specified' do
          component.release

          # should not be escaped, escaping happens at runtime because default value is a sub-command
          #   executed in the runtime container
          expect(java_opts).to include('-Dappdynamics.agent.applicationName=default application-name')
        end
      end

      context do
        let(:credentials) { super().merge 'node-name' => 'another-test-node-name' }

        it 'adds node_name from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.nodeName=another-test-node-name')
        end
      end

      context do
        let(:credentials) { super().merge 'port' => 'test-port' }

        it 'adds port to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.controller.port=test-port')
        end
      end

      context do
        let(:credentials) { super().merge 'ssl-enabled' => 'test-ssl-enabled' }

        it 'adds ssl_enabled to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.controller.ssl.enabled=test-ssl-enabled')
        end
      end

      context do
        let(:credentials) { super().merge 'account-name' => 'test-account-name' }

        it 'adds account_name to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.accountName=test-account-name')
        end
      end

      context do
        let(:credentials) { super().merge 'account-access-key' => 'test-account-access-key' }

        it 'adds account_access_key to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dappdynamics.agent.accountAccessKey=test-account-access-key')
        end
      end

      context do

        let(:environment) { { 'APPD_CONF_HTTP_URL' => 'http://foo.com' } }
        let(:conf_files) { described_class.instance_variable_get(:@conf_files) }

        it 'sets APPD_CONF_HTTP_URL env var to download config files from',
           cache_fixture: 'stub-app-dynamics-agent.zip' do

          config_files = %w[logging/log4j2.xml logging/log4j.xml app-agent-config.xml controller-info.xml
                            service-endpoint.xml transactions.xml custom-interceptors.xml
                            custom-activity-correlation.xml]

          config_files.each do |file|
            uri = "http://foo.com/java/#{file}"
            allow(application_cache).to receive(:get)
              .with(uri)
            stub_request(:head, uri)
              .with(headers: { 'Accept' => '*/*', 'Host' => 'foo.com', 'User-Agent' => 'Ruby' })
              .to_return(status: 200, body: '', headers: {})
          end
          component.compile
        end

      end

      context do
        let(:environment) { { 'APPD_CONF_HTTP_URL' => 'https://foo.com' } }

        it 'sets APPD_CONF_HTTP_URL env var to download config files over HTTPS',
           cache_fixture: 'stub-app-dynamics-agent.zip' do

          config_files = %w[logging/log4j2.xml logging/log4j.xml app-agent-config.xml controller-info.xml
                            service-endpoint.xml transactions.xml custom-interceptors.xml
                            custom-activity-correlation.xml]

          config_files.each do |file|
            uri = "https://foo.com/java/#{file}"
            allow(application_cache).to receive(:get)
              .with(uri)
            allow(Net::HTTP).to receive(:start).with('foo.com', 443, use_ssl: true).and_call_original
            stub_request(:head, uri)
              .with(headers: { 'Accept' => '*/*', 'Host' => 'foo.com', 'User-Agent' => 'Ruby' })
              .to_return(status: 200, body: '', headers: {})
          end
          component.compile
        end
      end

      context do
        let(:environment) { { 'APPD_CONF_HTTP_URL' => 'https://user:pass@foo.com' } }

        it 'sets APPD_CONF_HTTP_URL env var to download config files over HTTPS with Basic Auth',
           cache_fixture: 'stub-app-dynamics-agent.zip' do

          config_files = %w[logging/log4j2.xml logging/log4j.xml app-agent-config.xml controller-info.xml
                            service-endpoint.xml transactions.xml custom-interceptors.xml
                            custom-activity-correlation.xml]

          config_files.each do |file|
            allow(application_cache).to receive(:get)
              .with("https://user:pass@foo.com/java/#{file}")
            allow(Net::HTTP).to receive(:start).with('foo.com', 443, use_ssl: true).and_call_original
            stub_request(:head, "https://foo.com/java/#{file}")
              .with(headers: { 'Accept' => '*/*', 'Host' => 'foo.com', 'User-Agent' => 'Ruby',
                               'Authorization' => 'Basic dXNlcjpwYXNz' })
              .to_return(status: 200, body: '', headers: {})
          end
          component.compile
        end
      end

      context do

        let(:environment) { { 'APPD_CONF_DIR' => 'BOOT-INF/classes/appdynamics/conf' } }

        it 'sets APPD_CONF_DIR env var to copy config files from app dir',
           app_fixture: 'framework_app_dynamics_agent',
           cache_fixture: 'stub-app-dynamics-agent.zip' do

          component.compile
          expect(File.read(sandbox + 'ver21.1.0.31582/conf/app-agent-config.xml')).to include 'sourced by APPD_CONF_DIR'
        end
      end

      context do

        let(:environment) { { 'APPD_CONF_DIR' => 'BOOT-INF/classes/appdynamics/conf-false' } }

        it 'sets APPD_CONF_DIR env var to copy config files from incorrect app dir',
           app_fixture: 'framework_app_dynamics_agent',
           cache_fixture: 'stub-app-dynamics-agent.zip' do

          expect { component.compile }.to raise_error(RuntimeError, /AppDynamics configuration source dir/)
        end
      end
    end
  end
end
