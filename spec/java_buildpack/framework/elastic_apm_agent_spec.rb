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
require 'java_buildpack/framework/elastic_apm_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::ElasticApmAgent do
  include_context 'with component help'

  it 'does not detect without elastic-apm-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/elastic-apm/, %w[server_urls secret_token]).and_return(true)
    end

    it 'detects with elastic-apm-n/a service' do
      expect(component.detect).to eq("elastic-apm-agent=#{version}")
    end

    it 'downloads elastic-apm agent JAR',
       cache_fixture: 'stub-elastic-apm-agent.jar' do

      component.compile

      expect(sandbox + "elastic_apm_agent-#{version}.jar").to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'server_urls' => 'serverurl',
                                                                              'secret_token' => 'secret_token' })

      component.release

      expect(java_opts).to include("-javaagent:$PWD/.java-buildpack/elastic_apm_agent/elastic_apm_agent-#{version}.jar")
      expect(java_opts).to include('-Delastic.apm.home=$PWD/.java-buildpack/elastic_apm_agent')
      expect(java_opts).to include('-Delastic.apm.server_urls=serverurl')
      expect(java_opts).to include('-Delastic.apm.secret_token=secret_token')
      expect(java_opts).to include('-Delastic.apm.service_name=test-application-name')
      expect(java_opts).to include('-Delastic.apm.log_file_name=STDOUT')
    end

    context do
      let(:creds) do
        { 'secret_token' => 'test-secret_token',
          'server_urls' => 'different-serverurl',
          'service_name' => 'different-name',
          'foo' => 'bar',
          'capture_jmx_metrics' => 'object_name[java.lang:type=Memory] ' \
                                   'attribute[HeapMemoryUsage:metric_name=test_heap_metric]',
          'sub' => '$(echo \'Hello world!\') and stuff',
          'var' => '--> ${SOME_VAR} <--',
          'bool' => false,
          'nil' => nil }
      end

      it 'updates JAVA_OPTS with additional options' do
        allow(services).to receive(:find_service).and_return('credentials' => creds)

        component.release

        expect(java_opts).to include('-Delastic.apm.secret_token=test-secret_token')
        expect(java_opts).to include('-Delastic.apm.server_urls=different-serverurl')
        expect(java_opts).to include('-Delastic.apm.service_name=different-name')
        expect(java_opts).to include('-Delastic.apm.foo=bar')
        escaped = 'object_name\[java.lang:type\=Memory\]\ attribute\[HeapMemoryUsage:metric_name\=test_heap_metric\]'
        expect(java_opts).to include("-Delastic.apm.capture_jmx_metrics=#{escaped}")
        expect(java_opts).to include('-Delastic.apm.sub=\"$(echo \'Hello world!\') and stuff\"')
        expect(java_opts).to include('-Delastic.apm.var=\"--> ${SOME_VAR} <--\"')
      end
    end
  end
end
