# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/framework/spring_insight'

describe JavaBuildpack::Framework::SpringInsight do
  include_context 'component_helper'

  it 'should not detect without spring-insight-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/insight/).and_return(true)
      allow(services).to receive(:find_service).and_return('label'       => 'insight-1.0',
                                                           'credentials' => { 'dashboard_url' => 'test-uri' })
      allow(application_cache).to receive(:get).with('test-uri/services/config/agent-download')
                                  .and_yield(Pathname.new('spec/fixtures/stub-insight-agent.jar').open)
    end

    it 'should detect with spring-insight-n/a service' do
      expect(component.detect).to eq('spring-insight=1.0')
    end

    it 'should extract Spring Insight from the Uber Agent zip file inside the Agent Installer jar' do
      component.compile

      container_libs_dir     = app_dir + '.spring-insight/container-libs'
      extra_applications_dir = app_dir + '.spring-insight/extra-applications'

      expect(sandbox + 'weaver/insight-weaver-1.2.4-CI-SNAPSHOT.jar').to exist
      expect(container_libs_dir + 'insight-bootstrap-generic-1.2.3-CI-SNAPSHOT.jar').to exist
      expect(container_libs_dir + 'insight-bootstrap-tomcat-common-1.2.5-CI-SNAPSHOT.jar').to exist
      expect(sandbox + 'insight/conf/insight.properties').to exist
      expect(sandbox + 'insight/collection-plugins/test-collection-plugins').to exist
      expect(extra_applications_dir + 'insight-agent').to exist
      expect(extra_applications_dir + 'insight-agent/WEB-INF/lib/insight-agent-http-1.9.3-CI-SNAPSHOT.jar').to exist
      expect(extra_applications_dir + 'insight-agent/WEB-INF/lib/insight-agent-cloudfoundry-1.2.3.jar').to exist
      expect(container_libs_dir + 'cloudfoundry-runtime-1.2.3.jar').to exist
    end

    it 'should update JAVA_OPTS',
       app_fixture: 'framework_spring_insight' do

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/spring_insight/weaver/insight-weaver-1.2.4-CI-SNAPSHOT.jar')
      expect(java_opts).to include('-Dinsight.base=$PWD/.java-buildpack/spring_insight/insight')
      expect(java_opts).to include('-Dinsight.logs=$PWD/.java-buildpack/spring_insight/insight/logs')
      expect(java_opts).to include('-Daspectj.overweaving=true')
      expect(java_opts).to include('-Dorg.aspectj.tracing.factory=default')
    end
  end

end
