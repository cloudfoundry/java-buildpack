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
require 'java_buildpack/framework/dynatrace_one_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::DynatraceOneAgent do
  include_context 'component_helper'

  it 'does not detect without dynatrace|ruxit-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/ruxit|dynatrace/, %w(environmentid tenant),
                                                     %w(apitoken tenanttoken)).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'apitoken' => 'test-apitoken',
                                                                              'tenant'   => 'test-tenant',
                                                                              'server'   => 'test-server' })
      # allow(File).to receive(:file?).and_return(true)
      allow(application_cache).to receive(:get)
        .with('test-server/api/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&' \
        'Api-Token=test-apitoken')
        .and_yield(Pathname.new('spec/fixtures/stub-dynatrace-one-agent.zip').open, false)
    end

    it 'detects with dynatrace-n/a service' do
      expect(component.detect).to eq('dynatrace-one-agent=latest')
    end

    it 'downloads Dynatrace agent zip',
       cache_fixture: 'stub-dynatrace-one-agent.zip' do

      component.compile

      expect(sandbox + 'agent/lib64/liboneagentloader.so').to exist
      expect(sandbox + 'manifest.json').to exist
    end

    it 'does update JAVA_OPTS with environmentid and apitoken',
       app_fixture: 'framework_dynatrace_one_agent' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid' => 'test-tenant',
                                                                              'apitoken'      => 'test-apitoken' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/dynatrace_one_agent/agent/lib64/' \
      'liboneagentloader.so=server=https://test-tenant.live.dynatrace.com,tenant=test-tenant,' \
      'tenanttoken=token-from-file')
    end

    it 'updates JAVA_OPTS with custom server and deprecated tenanttoken',
       app_fixture: 'framework_dynatrace_one_agent' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'server'      => 'test-server',
                                                                              'tenant'      => 'test-tenant',
                                                                              'tenanttoken' => 'test-token' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/dynatrace_one_agent/agent/lib64/' \
      'liboneagentloader.so=server=test-server,tenant=test-tenant,' \
      'tenanttoken=test-token')
    end

    it 'updates JAVA_OPTS with custom server and apitoken',
       app_fixture: 'framework_dynatrace_one_agent' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'server'        => 'test-server',
                                                                              'environmentid' => 'test-tenant',
                                                                              'apitoken'      => 'test-apitoken' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/dynatrace_one_agent/agent/lib64/' \
      'liboneagentloader.so=server=test-server,tenant=test-tenant,' \
      'tenanttoken=token-from-file')
    end

    it 'updates environment variables',
       app_fixture: 'framework_dynatrace_one_agent' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid'   => 'test-tenant',
                                                                              'apitoken'        => 'test-apitoken' })
      component.release

      expect(environment_variables).to include('RUXIT_APPLICATIONID=test-application-name')
      expect(environment_variables).to include('RUXIT_HOST_ID=test-application-name_${CF_INSTANCE_INDEX}')
    end

    context do

      let(:environment) do
        { 'RUXIT_APPLICATIONID' => 'test-application-id',
          'RUXIT_HOST_ID'       => 'test-host-id' }
      end

      it 'does not update environment variables if they exist',
         app_fixture: 'framework_dynatrace_one_agent' do
        allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid'   => 'test-tenant',
                                                                                'apitoken'        => 'test-apitoken' })
        component.release

        expect(environment_variables).not_to include(/RUXIT_APPLICATIONID/)
        expect(environment_variables).not_to include(/RUXIT_HOST_ID/)
      end

    end

  end

end
