# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/framework/google_stackdriver_debugger'

describe JavaBuildpack::Framework::GoogleStackdriverDebugger do
  include_context 'with component help'

  it 'does not detect without google-stackdriver-debugger-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?)
        .with(/google-stackdriver-debugger/, 'PrivateKeyData').and_return(true)

      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'PrivateKeyData' => 'dGVzdC1wcml2YXRlLWtleS1kYXRh'
        }
      )
    end

    it 'detects with google-stackdriver-debugger-c-n/a service' do
      expect(component.detect).to eq("google-stackdriver-debugger=#{version}")
    end

    it 'unpacks the google stackdriver debugger tar',
       cache_fixture: 'stub-google-stackdriver-debugger.tar.gz' do

      component.compile

      expect(sandbox + 'cdbg_java_agent.so').to exist
    end

    it 'writes JSOn file',
       cache_fixture: 'stub-google-stackdriver-debugger.tar.gz' do

      component.compile

      expect(sandbox + 'svc.json').to exist
      expect(File.read(sandbox + 'svc.json')).to eq("test-private-key-data\n")
    end

    it 'updates JAVA_OPTS' do
      component.release
      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/google_stackdriver_debugger/cdbg_java_agent.so=' \
                                   '--logtostderr=1')
      expect(java_opts).to include('-Dcom.google.cdbg.auth.serviceaccount.enable=true')
      expect(java_opts).to include('-Dcom.google.cdbg.auth.serviceaccount.jsonfile=' \
                                   '$PWD/.java-buildpack/google_stackdriver_debugger/svc.json')
      expect(java_opts).to include('-Dcom.google.cdbg.module=test-application-name')
      expect(java_opts).to include('-Dcom.google.cdbg.version=test-application-version')
    end

  end

end
