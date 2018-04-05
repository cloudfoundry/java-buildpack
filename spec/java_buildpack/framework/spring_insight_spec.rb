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
require 'fileutils'
require 'internet_availability_helper'
require 'java_buildpack/framework/spring_insight'

describe JavaBuildpack::Framework::SpringInsight do
  include_context 'with component help'
  include_context 'with internet availability help'

  it 'does not detect without spring-insight-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?)
        .with(/p-insight/, 'agent_download_url', 'service_instance_id').and_return(true)
      allow(services).to receive(:find_service).and_return(
        'label'       => 'p-insight',
        'credentials' => {
          'version'             => '2.0.0',
          'agent_download_url'  => 'test-uri/services/config/agent-download',
          'agent_password'      => 'foo',
          'agent_username'      => 'bar',
          'service_instance_id' => '12345'
        }
      )
      allow(application_cache).to receive(:get)
        .with('test-uri/services/config/agent-download')
        .and_yield(Pathname.new('spec/fixtures/stub-insight-agent.jar').open, false)
    end

    it 'does detect with spring-insight-n/a service' do
      expect(component.detect).to eq('spring-insight=2.0.0')
    end

    it 'does extract Spring Insight from the Uber Agent zip file inside the Agent Installer jar' do
      component.compile

      expect(sandbox + 'weaver/insight-weaver-2.0.0-CI-SNAPSHOT.jar').to exist
      expect(sandbox + 'insight/conf/insight.properties').to exist
      expect(sandbox + 'insight/agent-plugins/insight-agent-rabbitmq-core-2.0.0-CI-SNAPSHOT.jar').to exist
    end

    it 'does guarantee that internet access is available when downloading' do
      expect_any_instance_of(JavaBuildpack::Util::Cache::InternetAvailability)
        .to receive(:available).with(true, 'The Spring Insight download location is always accessible')

      component.compile
    end

    it 'does update JAVA_OPTS',
       app_fixture: 'framework_spring_insight' do

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/spring_insight/weaver/' \
                                   'insight-weaver-1.2.4-CI-SNAPSHOT.jar')
      expect(java_opts).to include('-Dinsight.base=$PWD/.java-buildpack/spring_insight/insight')
      expect(java_opts).to include('-Dinsight.logs=$PWD/.java-buildpack/spring_insight/insight/logs')
      expect(java_opts).to include('-Daspectj.overweaving=true')
      expect(java_opts).to include('-Dorg.aspectj.tracing.factory=default')
    end
  end

  context do

    it 'does extract Spring Insight from the Uber Agent zip file and copy the ActiveMQ plugin' do
      allow(services).to receive(:one_service?)
        .with(/p-insight/, 'agent_download_url', 'service_instance_id').and_return(true)
      allow(services).to receive(:find_service).and_return(
        'label'       => 'p-insight',
        'credentials' => {
          'version'             => '2.0.0',
          'agent_download_url'  => 'test-uri/services/config/agent-download',
          'agent_password'      => 'foo',
          'agent_username'      => 'bar',
          'service_instance_id' => '12345',
          'agent_transport'     => 'activemq'
        }
      )
      allow(application_cache).to receive(:get)
        .with('test-uri/services/config/agent-download')
        .and_yield(Pathname.new('spec/fixtures/stub-insight-agent.jar').open, false)

      component.compile

      expect(sandbox + 'weaver/insight-weaver-2.0.0-CI-SNAPSHOT.jar').to exist
      expect(sandbox + 'insight/conf/insight.properties').to exist
      expect(sandbox + 'insight/agent-plugins/insight-agent-activemq-2.0.0-CI-SNAPSHOT.jar').to exist
    end

  end

end
