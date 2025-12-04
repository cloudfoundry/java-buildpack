# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2025 the original author or authors.
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
require 'java_buildpack/framework/cf_metrics_exporter'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::CfMetricsExporter do
  include_context 'with component help'

  let(:configuration) { { 'version' => '0.7.1', 'uri' => 'https://example.invalid/cf-metrics-exporter-0.7.1.jar' } }

  it 'does not detect by default' do
    expect(component.detect).to be_nil
  end

  context 'when enabled' do
    before do
      allow(environment_variables)
        .to receive(:[]).with('CF_METRICS_EXPORTER_ENABLED').and_return('true')
    end

    it 'detects' do
      expect(component.detect).to eq('cf-metrics-exporter=0.7.1')
    end

    it 'downloads the agent jar', cache_fixture: 'stub-download.jar' do
      component.compile
      expect(sandbox + 'cf-metrics-exporter-0.7.1.jar').to exist
    end

    it 'adds -javaagent without props when none provided' do
      component.release
      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/cf_metrics_exporter/cf-metrics-exporter-0.7.1.jar')
    end

    it 'adds -javaagent with props when CF_METRICS_EXPORTER_PROPS is set' do
      allow(environment_variables)
        .to receive(:[]).with('CF_METRICS_EXPORTER_PROPS').and_return('foo=bar,port=1234')

      component.release
      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/cf_metrics_exporter/cf-metrics-exporter-0.7.1.jar=foo=bar,port=1234')
    end
  end
end
