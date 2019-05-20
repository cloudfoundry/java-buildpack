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
require 'java_buildpack/framework/seeker_security_provider'

describe JavaBuildpack::Framework::SeekerSecurityProvider do
  include_context 'with component help'

  let(:configuration) do
    { 'some_property' => nil }
  end

  it 'does not detect without seeker service' do
    expect(component.detect).to be_falsey
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/seeker/).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with seeker service' do
      expect(component.detect).to be_truthy
    end

    context do
      let(:credentials) do
        { 'sensor_port' => '9911',
          'sensor_host' => 'localhost' }
      end

      it 'raises error if `enterprise_server_url` not specified' do
        expect { component.compile }.to raise_error(/'enterprise_server_url' credential must be set/)
      end
    end

    context do
      let(:credentials) do
        { 'sensor_port' => '9911',
          'sensor_host' => 'localhost',
          'enterprise_server_url' => 'some-url' }
      end

      it 'raises error if `seeker_server_url` not specified' do
        expect { component.compile }.to raise_error(/'seeker_server_url' credential must be set/)
      end
    end

    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.117:8082',
          'sensor_port' => '9911' }
      end

      it 'raises error if `sensor_host` not specified' do
        expect { component.compile }.to raise_error(/'sensor_host' credential must be set/)
      end

    end

    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.117:8082',
          'sensor_host' => 'localhost' }
      end

      it 'raises error if `sensor_port` not specified' do
        expect { component.compile }.to raise_error(/'sensor_port' credential must be set/)
      end

    end

    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.117:8082',
          'seeker_server_url' => 'http://10.120.9.117:9911',
          'sensor_host' => 'localhost',
          'sensor_port' => '9911' }
      end

      before do
        allow(component).to receive(:agent_direct_link).with(credentials).and_return('test-uri')
      end

      it 'expands Seeker agent zip for agent direct download',
         cache_fixture: 'seeker-java-agent.zip' do

        allow(component).to receive(:should_download_sensor).and_return(false)
        component.compile

        expect(sandbox + 'seeker-agent.jar').to exist

      end
      it 'Chooses downloading the agent for Seeker versions newer than 2018.05',
         cache_fixture: 'seeker-java-agent.zip' do
        agent_download_expected_dates = ['2018.06', '2018.07', '2018.08', '2018.09', '2018.10', '2018.11',
                                         '2018.12', '2019.01', '2019.02', '2019.03', '2019.04', '2019.05']
        agent_download_expected_dates.each do |seeker_version|
          json_version_mock_response =
            ["{\"publicName\":\"Seeker Enterprise Server\",\"version\":\"#{seeker_version}\"",
             ',"buildNumber":"20121550","scmBranch":"origin/release/v2018.06","scmRevision":"809"}'].join(' ')
          allow(component).to receive(:get_seeker_version_details)
            .with(credentials['enterprise_server_url']).and_return(json_version_mock_response)
          allow(component).to receive(:download_agent)
          component.compile
        end

      end
      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/seeker_security_provider/seeker-agent.jar')
      end

    end

    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.117:8082',
          'seeker_server_url' => 'http://10.120.9.117:9911',
          'sensor_host' => 'localhost',
          'sensor_port' => '9911' }
      end

      before do
        allow(component).to receive(:sensor_direct_link).with(credentials).and_return('test-uri')
      end

      it 'expands Seeker agent from within sensor zip',
         cache_fixture: 'sensor.zip' do
        allow(component).to receive(:should_download_sensor).and_return(true)
        component.compile

        expect(sandbox + 'seeker-agent.jar').to exist

      end

      it 'Chooses downloading the sensor for Seeker versions older than 2018.05 (including 2018.05)',
         cache_fixture: 'sensor.zip' do
        sensor_download_expected_dates = ['2018.05', '2018.04', '2018.03', '2018.02', '2018.01', '2017.12', '2017.11',
                                          '2017.10', '2017.09', '2017.08', '2017.05',
                                          '2017.04', '2017.03', '2017.02', '2017.01']
        sensor_download_expected_dates.each do |seeker_version|
          json_version_mock_response =
            ["{\"publicName\":\"Seeker Enterprise Server\",\"version\":\"#{seeker_version}\"",
             ',"buildNumber":"20121550","scmBranch":"origin/release/v2018.06","scmRevision":"809"}'].join(' ')
          allow(component).to receive(:get_seeker_version_details)
            .with(credentials['enterprise_server_url']).and_return(json_version_mock_response)
          allow(component).to receive(:fetch_agent_within_sensor).with(credentials)
          component.compile
        end

      end

      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/seeker_security_provider/seeker-agent.jar')
      end

    end
  end

end
