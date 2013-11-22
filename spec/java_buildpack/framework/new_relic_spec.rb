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
require 'java_buildpack/framework/new_relic'

module JavaBuildpack::Framework

  describe NewRelic, service_type: 'newrelic-n/a' do
    include_context 'component_helper'

    let(:service_credentials) { { 'licenseKey' => 'test-license-key' } }

    it 'should detect with newrelic-n/a service' do
      expect(component.detect).to eq("new-relic-agent=#{version}")
    end

    context do
      let(:vcap_services) { {} }

      it 'should not detect without newrelic-n/a service' do
        expect(component.detect).to be_nil
      end
    end

    context do
      let(:service_payload) { [{ 'credentials' => service_credentials }, { 'credentials' => service_credentials }] }

      it 'should fail with multiple newrelic-n/a services' do
        expect { component.detect }.to raise_error /Exactly one service/
      end
    end

    context do
      let(:service_payload) { [] }

      it 'should fail with zero newrelic-n/a services' do
        expect { component.detect }.to raise_error /Exactly one service/
      end
    end

    it 'should download New Relic agent JAR',
       cache_fixture: 'stub-new-relic.jar' do

      component.compile

      expect(app_dir + ".new-relic/new-relic-agent-#{version}.jar").to exist
    end

    it 'should copy resources',
       cache_fixture: 'stub-new-relic.jar' do

      component.compile

      expect(app_dir + '.new-relic/newrelic.yml').to exist
    end

    it 'should update JAVA_OPTS' do
      component.release

      expect(java_opts).to include("-javaagent:.new-relic/new-relic-agent-#{version}.jar")
      expect(java_opts).to include('-Dnewrelic.home=.new-relic')
      expect(java_opts).to include('-Dnewrelic.config.license_key=test-license-key')
      expect(java_opts).to include("-Dnewrelic.config.app_name='test-application-name'")
      expect(java_opts).to include('-Dnewrelic.config.log_file_path=.new-relic/logs')
    end

  end

end
