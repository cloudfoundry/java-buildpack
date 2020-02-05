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
require 'java_buildpack/framework/azure_application_insights_agent'

describe JavaBuildpack::Framework::AzureApplicationInsightsAgent do
  include_context 'with component help'

  let(:configuration) do
    { 'default_application_name' => nil }
  end

  it 'does not detect without azure-application-insights service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/azure-application-insights/, 'instrumentation_key')
                                               .and_return(true)
    end

    it 'detects with azure-application-insights service' do
      expect(component.detect).to eq("azure-application-insights-agent=#{version}")
    end

    it 'downloads Azure Application Insights agent JAR',
       cache_fixture: 'stub-azure-application-insights-agent.jar' do

      component.compile

      expect(sandbox + "azure_application_insights_agent-#{version}.jar").to exist
    end

    it 'copies resources',
       cache_fixture: 'stub-azure-application-insights-agent.jar' do

      component.compile

      expect(sandbox + 'AI-Agent.xml').to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service)
        .and_return('credentials' => { 'instrumentation_key' => 'test-instrumentation-key' })

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/azure_application_insights_agent/' \
                                   "azure_application_insights_agent-#{version}.jar")
      expect(java_opts).to include('-DAPPLICATION_INSIGHTS_IKEY=test-instrumentation-key')
    end

  end

end
