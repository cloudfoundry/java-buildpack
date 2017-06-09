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
require 'java_buildpack/framework/metric_writer'

describe JavaBuildpack::Framework::MetricWriter do
  include_context 'component_helper'

  it 'does not detect without metric-forwarder service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/metrics-forwarder/, 'access_key', 'endpoint').and_return(true)
    end

    it 'detects with metric-forwarder service' do
      expect(component.detect).to eq("metric-writer=#{version}")
    end

    it 'downloads Metric Writer JAR',
       cache_fixture: 'stub-metric-writer.jar' do

      component.compile

      expect(sandbox + "metric_writer-#{version}.jar").to exist
    end

    it 'adds the metric writer to the additional libraries in compile when needed',
       cache_fixture: 'stub-metric-writer.jar' do

      component.compile

      expect(additional_libraries).to include(sandbox + "metric_writer-#{version}.jar")
    end

    it 'adds the metric writer to the additional libraries in release when needed',
       cache_fixture: 'stub-metric-writer.jar' do

      allow(services).to receive(:find_service).and_return('credentials' => { 'access_key' => 'test-access-key',
                                                                              'endpoint'   => 'https://test-endpoint' })

      component.release

      expect(additional_libraries).to include(sandbox + "metric_writer-#{version}.jar")
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'access_key' => 'test-access-key',
                                                                              'endpoint'   => 'https://test-endpoint' })

      component.release

      expect(java_opts).to include('-Dcloudfoundry.metrics.accessToken=test-access-key')
      expect(java_opts).to include('-Dcloudfoundry.metrics.applicationId=test-application-id')
      expect(java_opts).to include('-Dcloudfoundry.metrics.endpoint=https://test-endpoint')
      expect(java_opts).to include('-Dcloudfoundry.metrics.instanceId=$CF_INSTANCE_GUID')
      expect(java_opts).to include('-Dcloudfoundry.metrics.instanceIndex=$CF_INSTANCE_INDEX')
    end

  end

end
