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
require 'fileutils'
require 'java_buildpack/application'
require 'java_buildpack/framework/spring_insight'

module JavaBuildpack::Framework

  describe SpringInsight do

    let(:application_cache) { double('ApplicationCache') }
    let(:java_opts) { [] }
    let(:vcap_application) { {} }
    let(:vcap_services) { {} }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with spring-insight-n/a service' do
      vcap_services['insight-n/a'] = [{ 'label' => 'insight-1.0', 'credentials' => { 'dashboard_url' => 'test-uri' } }]
      vcap_application['application_name'] = 'test-application-name'

      detected = SpringInsight.new(
              vcap_application: vcap_application,
              vcap_services: vcap_services
      ).detect

      expect(detected).to eq('spring-insight=1.0')
    end

    it 'should extract Spring Insight from the Uber Agent zip file inside the Agent Installer jar' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri/services/config/agent-download').and_yield(File.open('spec/fixtures/stub-insight-agent.jar'))
        vcap_services['insight-n/a'] = [{ 'label' => 'insight-1.0', 'credentials' => { 'dashboard_url' => 'test-uri/' } }]
        vcap_application['application_name'] = 'test-application-name'

        container_libs_directory = File.join root, '.container-libs'
        extra_apps_directory = File.join root, '.extra-applications'

        SpringInsight.new(
                app_dir: root,
                vcap_application: vcap_application,
                vcap_services: vcap_services
        ).compile

        insight_home = File.join root, '.insight'
        expect(File.exists? File.join(insight_home, 'weaver', 'insight-weaver-1.2.4-CI-SNAPSHOT.jar')).to be_true
        expect(File.exists? File.join(container_libs_directory, 'insight-bootstrap-generic-1.2.3-CI-SNAPSHOT.jar')).to be_true
        expect(File.exists? File.join(container_libs_directory, 'insight-bootstrap-tomcat-common-1.2.5-CI-SNAPSHOT.jar')).to be_true
        expect(File.exists? File.join(insight_home, 'insight', 'conf', 'insight.properties')).to be_true
        expect(File.exists? File.join(insight_home, 'insight', 'collection-plugins', 'test-collection-plugins')).to be_true
        expect(File.exists? File.join(extra_apps_directory, 'insight-agent')).to be_true
      end
    end

    it 'should update JAVA_OPTS' do
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['insight-n/a'] = [{ 'label' => 'insight-1.0', 'credentials' => { 'dashboard_url' => 'test-uri' } }]

      SpringInsight.new(
              app_dir: 'spec/fixtures/framework_spring_insight',
              application: JavaBuildpack::Application.new('spec/fixtures/framework_spring_insight'),
              java_opts: java_opts,
              vcap_application: vcap_application,
              vcap_services: vcap_services
      ).release

      expect(java_opts).to include('-javaagent:.insight/weaver/insight-weaver-1.2.4-CI-SNAPSHOT.jar')
      expect(java_opts).to include('-Dinsight.base=.insight/insight')
      expect(java_opts).to include('-Dinsight.logs=.insight/insight/logs')
      expect(java_opts).to include('-Daspectj.overweaving=true')
      expect(java_opts).to include('-Dorg.aspectj.tracing.factory=default')
      expect(java_opts).to include('-Dagent.name.override=test-application-name')
    end

  end

end
