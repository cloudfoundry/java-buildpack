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
require 'java_buildpack/framework/google_stackdriver_profiler'

describe JavaBuildpack::Framework::GoogleStackdriverProfiler do
  include_context 'with component help'

  it 'does not detect without google-stackdriver-profiler service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?)
        .with(/google-stackdriver-profiler/, 'PrivateKeyData').and_return(true)

      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'PrivateKeyData' => 'eyJwcm9qZWN0X2lkIjoidGVzdC1wcm9qZWN0LWlkIn0='
        }
      )
    end

    it 'detects with google-stackdriver-profiler service' do
      expect(component.detect).to eq("google-stackdriver-profiler=#{version}")
    end

    it 'unpacks the google stackdriver debugger tar',
       cache_fixture: 'stub-google-stackdriver-profiler.tar.gz' do

      component.compile

      expect(sandbox + 'profiler_java_agent.so').to exist
    end

    it 'writes JSON file',
       cache_fixture: 'stub-google-stackdriver-profiler.tar.gz' do

      component.compile

      expect(sandbox + 'svc.json').to exist
      expect(File.read(sandbox + 'svc.json')).to eq("{\"project_id\":\"test-project-id\"}\n")
    end

    it 'updates JAVA_OPTS' do
      component.release
      expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/google_stackdriver_profiler/' \
                                   'profiler_java_agent.so=--logtostderr=1,-cprof_project_id=test-project-id,' \
                                   '-cprof_service=test-application-name,' \
                                   '-cprof_service_version=test-application-version')

      expect(environment_variables).to include('GOOGLE_APPLICATION_CREDENTIALS=' \
                                               '$PWD/.java-buildpack/google_stackdriver_profiler/svc.json')
    end

  end

end
