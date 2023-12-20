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
require 'java_buildpack/framework/open_telemetry_javaagent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::OpenTelemetryJavaagent do
  include_context 'with component help'

  let(:configuration) { { 'version' => '1.27.0' } }
  let(:vcap_application) { { 'application_name' => 'GreatServiceTM' } }

  it 'does not detect without otel-collector service bind' do
    expect(component.detect).to be_nil
  end

  context 'when detected' do

    before do
      allow(services).to receive(:one_service?).with(/otel-collector/).and_return(true)
    end

    it 'detects with opentelemetry-javaagent' do
      expect(component.detect).to eq("open-telemetry-javaagent=#{version}")
    end

    it 'downloads the opentelemetry javaagent jar', cache_fixture: 'stub-download.jar' do

      component.compile

      expect(sandbox + "open_telemetry_javaagent-#{version}.jar").to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'otel.exporter.otlp.endpoint' => 'https://my-collector-endpoint',
                                                                              'ignored' => 'not used',
                                                                              'otel.foo' => 'bar' })
      component.release

      expect(java_opts).to include(
        "-javaagent:$PWD/.java-buildpack/open_telemetry_javaagent/open_telemetry_javaagent-#{version}.jar"
      )
      expect(java_opts).to include('-Dotel.exporter.otlp.endpoint=https://my-collector-endpoint')
      expect(java_opts).to include('-Dotel.foo=bar')
    end

    it 'sets the service name from the application name' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'otel.exporter.otlp.endpoint' => 'https://my-collector-endpoint',
                                                                              'ignored' => 'not used',
                                                                              'otel.foo' => 'bar' })
      component.release

      expect(java_opts).to include('-Dotel.service.name=GreatServiceTM')
    end

  end

end
