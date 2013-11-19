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
require 'java_buildpack/framework/app_dynamics'

module JavaBuildpack::Framework

  describe AppDynamics, service_type: 'app-dynamics-n/a' do
    include_context 'component_helper'

    let(:configuration) { { 'tier_name' => 'test-tier-name' } }
    let(:service_credentials) { { 'host-name' => 'test-host-name' } }

    it 'should detect with app-dynamics-n/a service' do
      expect(component.detect).to eq("appdynamics-agent=#{version}")
    end

    context do
      let(:vcap_services) { {} }

      it 'should not detect without app-dynamics-n/a service' do
        detected = AppDynamics.new(
            vcap_services: vcap_services
        ).detect

        expect(detected).to be_nil
      end
    end

    context do
      let(:service_payload) { [{ 'credentials' => service_credentials }, { 'credentials' => service_credentials }] }

      it 'should fail with multiple app-dynamics-n/a services' do
        expect { component.detect }.to raise_error /Exactly one service/
      end
    end

    context do
      let(:service_payload) { [] }

      it 'should fail with zero app-dynamics-n/a services' do
        expect { component.detect }.to raise_error /Exactly one service/
      end
    end

    it 'should expand AppDynamics agent zip',
       cache_fixture: 'stub-app-dynamics-agent.zip' do

      component.compile

      expect(app_dir + '.app-dynamics/javaagent.jar').to exist
    end

    it 'should update JAVA_OPTS' do
      component.release

      expect(java_opts).to include('-javaagent:.app-dynamics/javaagent.jar')
      expect(java_opts).to include('-Dappdynamics.controller.hostName=test-host-name')
      expect(java_opts).to include("-Dappdynamics.agent.applicationName='test-application-name'")
      expect(java_opts).to include("-Dappdynamics.agent.tierName='test-tier-name'")
      expect(java_opts).to include('-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : ' +
                                       '\'.*instance_id[": ]*"\([a-z0-9]\+\)".*\')')
    end

    context do
      let(:service_credentials) { {} }

      it 'should raise error if host-name not specified' do
        expect { component.release }.to raise_error /'host-name' credential must be set/
      end
    end

    context do
      let(:service_credentials) { super().merge 'port' => 'test-port' }

      it 'should add port to JAVA_OPTS if specified' do
        component.release

        expect(java_opts).to include('-Dappdynamics.controller.port=test-port')
      end
    end

    context do
      let(:service_credentials) { super().merge 'ssl-enabled' => 'test-ssl-enabled' }

      it 'should add ssl_enabled to JAVA_OPTS if specified' do
        component.release

        expect(java_opts).to include('-Dappdynamics.controller.ssl.enabled=test-ssl-enabled')
      end
    end

    context do
      let(:service_credentials) { super().merge 'account-name' => 'test-account-name' }

      it 'should add account_name to JAVA_OPTS if specified' do
        component.release

        expect(java_opts).to include('-Dappdynamics.agent.accountName=test-account-name')
      end
    end

    context do
      let(:service_credentials) { super().merge 'account-access-key' => 'test-account-access-key' }

      it 'should add account_access_key to JAVA_OPTS if specified' do
        component.release

        expect(java_opts).to include('-Dappdynamics.agent.accountAccessKey=test-account-access-key')
      end
    end

  end

end
