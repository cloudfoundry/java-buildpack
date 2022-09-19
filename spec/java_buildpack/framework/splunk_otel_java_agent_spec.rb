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
require 'java_buildpack/framework/splunk_otel_java_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::SplunkOtelJavaAgent do
  include_context 'with component help'

  let(:configuration) { { 'version' => '1.16.0' } }
  let(:vcap_application) { { 'application_name' => 'GreatServiceTM' } }

  it 'does not detect without splunk-o11y service bind' do
    expect(component.detect).to be_nil
  end

  context 'when detected' do

    before do
      allow(services).to receive(:one_service?).with(/^splunk-o11y$/).and_return(true)
    end

    it 'detects with splunk-otel-java' do
      expect(component.detect).to eq("splunk-otel-java-agent=#{version}")
    end

    it 'downloads the splunk otel javaagent jar', cache_fixture: 'stub-splunk-otel-javaagent.jar' do

      component.compile

      expect(sandbox + "splunk_otel_java_agent-#{version}.jar").to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'splunk.access.token' => 'sekret',
                                                                              'ignored' => 'not used',
                                                                              'otel.foo' => 'bar' })
      component.release

      expect(java_opts).to include(
        "-javaagent:$PWD/.java-buildpack/splunk_otel_java_agent/splunk_otel_java_agent-#{version}.jar"
      )
      expect(java_opts).to include('-Dsplunk.access.token=sekret')
      expect(java_opts).to include('-Dotel.foo=bar')
    end

    it 'sets the service name from the application name' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'splunk.access.token' => 'sekret' })
      # allow(details).to be( { 'application_name' => 'dick' })

      component.release

      expect(java_opts).to include('-Dotel.service.name=GreatServiceTM')
    end

  end

end
