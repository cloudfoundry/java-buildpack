# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/framework/ruxit_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::RuxitAgent do
  include_context 'component_helper'

  it 'does not detect without ruxit-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/ruxit/, 'tenant', 'tenanttoken').and_return(true)
    end

    it 'detects with ruxit-n/a service' do
      expect(component.detect).to eq("ruxit-agent=#{version}")
    end

    it 'downloads Ruxit agent zip',
       cache_fixture: 'stub-ruxit-agent.zip' do

      component.compile

      expect(sandbox + 'agent/lib64/libruxitagentloader.so').to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'tenant'      => 'test-tenant',
                                                                              'tenanttoken' => 'test-token' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/ruxit_agent/agent/lib64/libruxitagentloader.so=' \
      'server=https://test-tenant.live.ruxit.com:443/communication,tenant=test-tenant,tenanttoken=test-token')
    end

    it 'updates JAVA_OPTS with custom server' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'server'      => 'test-server',
                                                                              'tenant'      => 'test-tenant',
                                                                              'tenanttoken' => 'test-token' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/ruxit_agent/agent/lib64/libruxitagentloader.so=' \
      'server=test-server,tenant=test-tenant,tenanttoken=test-token')
    end

    it 'updates environment variables' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'tenant'      => 'test-tenant',
                                                                              'tenanttoken' => 'test-token' })
      component.release

      expect(environment_variables).to include('RUXIT_APPLICATIONID=test-application-name')
      expect(environment_variables).to include('RUXIT_CLUSTER_ID=test-application-name')
      expect(environment_variables).to include('RUXIT_HOST_ID=test-application-name_${CF_INSTANCE_INDEX}')
    end

    context do

      let(:environment) do
        { 'RUXIT_APPLICATIONID' => 'test-application-id',
          'RUXIT_CLUSTER_ID'    => 'test-cluster-id',
          'RUXIT_HOST_ID'       => 'test-host-id' }
      end

      it 'does not update environment variables if they exist', :show_output do
        allow(services).to receive(:find_service).and_return('credentials' => { 'tenant'      => 'test-tenant',
                                                                                'tenanttoken' => 'test-token' })
        component.release

        expect(environment_variables).not_to include(/RUXIT_APPLICATIONID/)
        expect(environment_variables).not_to include(/RUXIT_CLUSTER_ID/)
        expect(environment_variables).not_to include(/RUXIT_HOST_ID/)
      end

    end

  end

end
