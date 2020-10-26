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
require 'java_buildpack/framework/checkmarx_iast_agent'

describe JavaBuildpack::Framework::CheckmarxIastAgent do
  include_context 'with component help'

  it 'does not detect without checkmarx-iast service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/^checkmarx-iast$/, 'server').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'server' => 'test-server' })

      allow(application_cache).to receive(:get)
        .with('test-server/iast/compilation/download/JAVA')
        .and_yield(Pathname.new('spec/fixtures/stub-checkmarx-agent.zip').open, false)
    end

    it 'detects with checkmarx-iast service' do
      expect(component.detect).to eq('checkmarx-iast-agent=')
    end

    it 'downloads agent',
       cache_fixture: 'stub-checkmarx-agent.zip' do

      component.compile

      expect(sandbox + 'cx-launcher.jar').to exist
    end

    it 'appends override configuration',
       cache_fixture: 'stub-checkmarx-agent.zip' do

      component.compile

      expect(File.read(sandbox + 'cx_agent.override.properties')).to eq('test-data

enableWeavedClassCache=false
')
    end

    it 'updates JAVA_OPTS' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/checkmarx_iast_agent/cx-launcher.jar')
      expect(java_opts).to include('-Dcx.logToConsole=true')
      expect(java_opts).to include('-Dcx.appName=test-application-name')
      expect(java_opts).to include('-DcxAppTag=test-application-name')
      expect(java_opts).to include('-DcxTeam=CxServer')
    end

  end

end
