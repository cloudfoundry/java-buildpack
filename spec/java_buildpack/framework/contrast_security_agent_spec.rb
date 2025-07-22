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
require 'java_buildpack/framework/contrast_security_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::ContrastSecurityAgent do
  include_context 'with component help'

  it 'does not detect without contrastsecurity service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/contrast-security/, 'api_key', 'service_key', 'teamserver_url',
                                                     'username').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'teamserver_url' => 'https://host.com',
                                                                              'username' => 'contrast_user',
                                                                              'api_key' => 'api_key_test',
                                                                              'service_key' => 'service_key_test',
                                                                              'proxy_host' => 'proxy_host_test',
                                                                              'proxy_port' => 8080,
                                                                              'proxy_user' => 'proxy_user_test',
                                                                              'proxy_pass' => 'proxy_password_test',
                                                                              'CONTRAST__INVENTORY__LIBRARY_DIRS' =>
                                                                                '/lib/dir',
                                                                              'CONTRAST__API__TIMEOUT_MS' => '30000',
                                                                              'CONTRAST__API__URL' =>
                                                                                'invalid_override_url' })
    end

    it 'detects with contrastsecurity service' do
      expect(component.detect).to eq("contrast-security-agent=#{version}")
    end

    it 'downloads Contrast Security agent JAR',
       cache_fixture: 'stub-contrast-security-agent.jar' do

      component.compile
      expect(sandbox + 'contrast-engine-0.0.0.jar').to exist
    end

    it 'uses contrast-engine for versions < 3.4.3' do

      tokenized_version = JavaBuildpack::Util::TokenizedVersion.new('3.4.2_756')
      allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item) do |&block|
        block&.call(tokenized_version)
      end.and_return([tokenized_version, uri])

      component.release
      expect(java_opts.to_s).to include('contrast-engine-3.4.2.jar')
    end

    it 'uses java-agent for versions >= 3.4.3' do
      tokenized_version = JavaBuildpack::Util::TokenizedVersion.new('3.4.3_000')
      allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item) do |&block|
        block&.call(tokenized_version)
      end.and_return([tokenized_version, uri])

      component.release
      expect(java_opts.to_s).to include('java-agent-3.4.3.jar')
    end

    it 'updates JAVA_OPTS to enable the agent' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/contrast_security_agent/contrast-engine-0.0.0.jar')
    end

    it 'does not override app name if there is an existing appname' do
      java_opts.add_system_property('contrast.override.appname', 'NAME_ALREADY_OVERRIDDEN')

      component.release

      expect(java_opts).to include('-Dcontrast.override.appname=NAME_ALREADY_OVERRIDDEN')
      expect(environment_variables).not_to include('CONTRAST__APPLICATION__NAME=test-application-name')
    end

    it 'does not override app name if there is an existing name' do
      java_opts.add_system_property('contrast.application.name', 'NAME_ALREADY_OVERRIDDEN')

      component.release

      expect(java_opts).to include('-Dcontrast.application.name=NAME_ALREADY_OVERRIDDEN')
      expect(environment_variables).not_to include('CONTRAST__APPLICATION__NAME=test-application-name')
    end

    it 'sets in env vars the credentials for connecting to Contrast UI' do
      component.release

      expect(environment_variables).to include('CONTRAST__API__URL=https://host.com/Contrast')
      expect(environment_variables).to include('CONTRAST__API__API_KEY=api_key_test')
      expect(environment_variables).to include('CONTRAST__API__SERVICE_KEY=service_key_test')
      expect(environment_variables).to include('CONTRAST__API__USER_NAME=contrast_user')
    end

    it 'sets in env vars the working directory for Contrast' do
      component.release

      expect(environment_variables).to include('CONTRAST__AGENT__CONTRAST_WORKING_DIR=$TMPDIR')
    end

    it 'sets in env vars the proxy settings when using a proxy' do
      component.release

      expect(environment_variables).to include('CONTRAST__API__PROXY__HOST=proxy_host_test')
      expect(environment_variables).to include('CONTRAST__API__PROXY__PORT=8080')
      expect(environment_variables).to include('CONTRAST__API__PROXY__USER=proxy_user_test')
      expect(environment_variables).to include('CONTRAST__API__PROXY__PASS=proxy_password_test')
    end

    it 'sets in env vars any other CONTRAST_ settings that exist' do
      component.release

      # Sets them without knowing what they are ahead of time
      expect(environment_variables).to include('CONTRAST__INVENTORY__LIBRARY_DIRS=/lib/dir')
      expect(environment_variables).to include('CONTRAST__API__TIMEOUT_MS=30000')
    end

    it 'specifically named settings override any generic CONTRAST__ settings' do
      component.release

      # The standard property `teamserver_url` was set along with CONTRAST__API__URL, so the former must be used
      expect(environment_variables).to include('CONTRAST__API__URL=https://host.com/Contrast')
    end

  end

  # Test with different settings from the service broker
  context do

    before do
      allow(services).to receive(:one_service?).with(/contrast-security/, 'api_key', 'service_key', 'teamserver_url',
                                                     'username').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'teamserver_url' => 'https://host.com',
                                                                              'username' => 'contrast_user',
                                                                              'api_key' => 'api_key_test',
                                                                              'service_key' => 'service_key_test' })
    end

    it 'proxy settings not applied to env vars when not set by broker' do
      component.release

      # convert to string to search for the env var by name
      env_var_str = environment_variables.to_s

      expect(env_var_str).not_to include('CONTRAST__API__PROXY__HOST')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__PORT')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__USER')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__PASS')
    end

  end

  # Test with null and empty values for the proxy settings
  context do

    before do
      allow(services).to receive(:one_service?).with(/contrast-security/, 'api_key', 'service_key', 'teamserver_url',
                                                     'username').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'teamserver_url' => 'https://host.com',
                                                                              'username' => 'contrast_user',
                                                                              'api_key' => 'api_key_test',
                                                                              'service_key' => 'service_key_test',
                                                                              # Test nil and empty values
                                                                              'proxy_host' => nil,
                                                                              'CONTRAST__IGNORE_01' => '',
                                                                              'CONTRAST__IGNORE_02' => nil })
    end

    it 'proxy settings handle nil and empty' do
      component.release

      # convert to string to search for the env var by name
      env_var_str = environment_variables.to_s

      expect(env_var_str).not_to include('CONTRAST__API__PROXY__HOST')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__PORT')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__USER')
      expect(env_var_str).not_to include('CONTRAST__API__PROXY__PASS')
      expect(env_var_str).not_to include('CONTRAST__IGNORE_01')
      expect(env_var_str).not_to include('CONTRAST__IGNORE_02')
    end

  end

end
