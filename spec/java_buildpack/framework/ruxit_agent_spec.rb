# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2016 the original author or authors.
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
      allow(services).to receive(:find_service).and_return('credentials' => { 'tenant' => 'testtenant',
                                                                              'tenanttoken' => 'testtoken' })
      component.release

      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/ruxit_agent/agent/lib64/libruxitagentloader.so='\
      'server=https://testtenant.live.ruxit.com:443/communication,tenant=testtenant,tenanttoken=testtoken')
    end

  end

end
