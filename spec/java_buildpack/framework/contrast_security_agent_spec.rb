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
      allow(services).to receive(:find_service).and_return('credentials' => { 'teamserver_url' => 'a_url',
                                                                              'username' => 'contrast_user',
                                                                              'api_key' => 'api_test',
                                                                              'service_key' => 'service_test' })
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

    it 'updates JAVA_OPTS' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/contrast_security_agent/contrast-engine-0.0.0.jar' \
                                   '=$PWD/.java-buildpack/contrast_security_agent/contrast.config')
      expect(java_opts).to include('-Dcontrast.dir=$TMPDIR')
      expect(java_opts).to include('-Dcontrast.override.appname=test-application-name')
    end

    it 'created contrast.config',
       cache_fixture: 'stub-contrast-security-agent.jar' do

      component.compile
      expect(sandbox + 'contrast.config').to exist
    end

    it 'does not override app name if there is an existing appname' do
      java_opts.add_system_property('contrast.override.appname', 'NAME_ALREADY_OVERRIDDEN')

      component.release

      expect(java_opts).to include('-Dcontrast.override.appname=NAME_ALREADY_OVERRIDDEN')
      expect(java_opts).not_to include('-Dcontrast.override.appname=test-application-name')
    end

  end

end
