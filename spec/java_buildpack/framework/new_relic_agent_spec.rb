# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/framework/new_relic_agent'

describe JavaBuildpack::Framework::NewRelicAgent do
  include_context 'component_helper'

  it 'should not detect without newrelic-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/newrelic/).and_return(true)
    end

    it 'should detect with newrelic-n/a service' do
      expect(component.detect).to eq("new-relic-agent=#{version}")
    end

    it 'should download New Relic agent JAR',
       cache_fixture: 'stub-new-relic-agent.jar' do

      component.compile

      expect(sandbox + "new_relic_agent-#{version}.jar").to exist
    end

    it 'should copy resources',
       cache_fixture: 'stub-new-relic-agent.jar' do

      component.compile

      expect(sandbox + 'newrelic.yml').to exist
    end

    it 'should update JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'licenseKey' => 'test-license-key' })

      component.release

      expect(java_opts).to include("-javaagent:$PWD/.java-buildpack/new_relic_agent/new_relic_agent-#{version}.jar")
      expect(java_opts).to include('-Dnewrelic.home=$PWD/.java-buildpack/new_relic_agent')
      expect(java_opts).to include('-Dnewrelic.config.license_key=test-license-key')
      expect(java_opts).to include("-Dnewrelic.config.app_name='test-application-name'")
      expect(java_opts).to include('-Dnewrelic.config.log_file_path=$PWD/.java-buildpack/new_relic_agent/logs')
    end

  end

end
