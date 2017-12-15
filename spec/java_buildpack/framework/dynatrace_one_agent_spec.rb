# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

  it 'does not detect without dynatrace-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/dynatrace/, 'apitoken', 'environmentid').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid' => 'test-environmentid',
                                                                              'apiurl'        => 'test-apiurl',
                                                                              'apitoken'      => 'test-apitoken' })

      allow(application_cache).to receive(:get)
        .with('test-apiurl/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&' \
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

    it 'updates JAVA_OPTS with agent loader',
       app_fixture: 'framework_dynatrace_one_agent' do

      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/dynatrace_one_agent/agent/lib64/' \
        'liboneagentloader.so')
    end

    it 'updates environment variables',
       app_fixture: 'framework_dynatrace_one_agent' do

      component.release

      expect(environment_variables).to include('DT_APPLICATIONID=test-application-name')
      expect(environment_variables).to include('DT_HOST_ID=test-application-name_${CF_INSTANCE_INDEX}')
      expect(environment_variables).to include('DT_TENANT=test-environmentid')
      expect(environment_variables).to include('DT_TENANTTOKEN=token-from-file')
      expect(environment_variables).to include('DT_CONNECTION_POINT=' \
        '"https://endpoint1/communication;https://endpoint2/communication"')
    end

    context do

      let(:environment) do
        { 'DT_APPLICATIONID' => 'test-application-id',
          'DT_HOST_ID'       => 'test-host-id' }
      end

      it 'does not update environment variables if they exist',
         app_fixture: 'framework_dynatrace_one_agent' do

        component.release

        expect(environment_variables).not_to include(/DT_APPLICATIONID/)
        expect(environment_variables).not_to include(/DT_HOST_ID/)
      end

    end

    context do

      before do
        allow(services).to receive(:one_service?).with(/dynatrace/, 'apitoken', 'environmentid').and_return(true)
        allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid' => 'test-environmentid',
                                                                                'apiurl'        => 'test-apiurl',
                                                                                'apitoken'      => 'test-apitoken' })
        allow(application_cache).to receive(:get)
          .with('test-apiurl/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64' \
            '&Api-Token=test-apitoken')
          .and_raise(RuntimeError.new('service interrupt'))
      end

      it 'fails on download error on default' do
        expect { component.compile }.to raise_error(RuntimeError)
      end

    end

    context do

      before do
        allow(services).to receive(:one_service?).with(/dynatrace/, 'apitoken', 'environmentid').and_return(true)
        allow(services).to receive(:find_service).and_return('credentials' => { 'environmentid' => 'test-environmentid',
                                                                                'apiurl'        => 'test-apiurl',
                                                                                'apitoken'      => 'test-apitoken',
                                                                                'skiperrors'    => 'true' })
        allow(application_cache).to receive(:get)
          .with('test-apiurl/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64' \
            '&Api-Token=test-apitoken')
          .and_raise(RuntimeError.new('service interrupt'))
      end

      it 'skips errors during compile and writes error file' do
        component.compile
        expect(sandbox + 'dynatrace_download_error').to exist
      end

      it 'does not do anything during release' do
        component.compile
        component.release

        expect(java_opts).not_to include('-agentpath:$PWD/.java-buildpack/dynatrace_one_agent/agent/lib64/' \
          'liboneagentloader.so')
      end

    end

  end

end
