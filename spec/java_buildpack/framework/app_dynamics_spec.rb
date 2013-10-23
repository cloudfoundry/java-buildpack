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
require 'java_buildpack/application'
require 'java_buildpack/framework/app_dynamics'

module JavaBuildpack::Framework

  describe AppDynamics do

    APP_DYNAMICS_VERSION = JavaBuildpack::Util::TokenizedVersion.new('3.7.11')

    APP_DYNAMICS_DETAILS = [APP_DYNAMICS_VERSION, 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:java_opts) { [] }
    let(:vcap_application) { {} }
    let(:vcap_services) { {} }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with app-dynamics-n/a service' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-naMe' => 'test-host-name' } }]

      detected = AppDynamics.new(
          vcap_services: vcap_services
      ).detect

      expect(detected).to eq('appdynamics-agent=3.7.11')
    end

    it 'should not detect without app-dynamics-n/a service' do
      detected = AppDynamics.new(
          vcap_services: vcap_services
      ).detect

      expect(detected).to be_nil
    end

    it 'should fail with multiple app-dynamics-n/a services' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_services['app-dynamics-n/a'] = [
          { 'credentials' => { 'host-naMe' => 'test-host-name' } },
          { 'credentials' => { 'host-naMe' => 'test-host-name' } }
      ]

      expect do
        AppDynamics.new(
            vcap_services: vcap_services
        ).detect
      end.to raise_error
    end

    it 'should fail with zero app-dynamics-n/a services' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_services['app-dynamics-n/a'] = []

      expect do
        AppDynamics.new(
            vcap_services: vcap_services
        ).detect
      end.to raise_error
    end

    it 'should expand AppDynamics agent zip' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-app-dynamics-agent.zip'))
        vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name' } }]

        AppDynamics.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            vcap_services: vcap_services
        ).compile

        expect(File.exists? File.join(root, '.app-dynamics', 'javaagent.jar')).to be_true
      end
    end

    it 'should update JAVA_OPTS' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name' } }]

      AppDynamics.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          application: JavaBuildpack::Application.new('/tmp'),
          vcap_services: vcap_services,
          configuration: { 'tier_name' => 'test-tier-name' }
      ).release

      expect(java_opts).to include('-javaagent:.app-dynamics/javaagent.jar')
      expect(java_opts).to include('-Dappdynamics.controller.hostName=test-host-name')
      expect(java_opts).to include("-Dappdynamics.agent.applicationName='test-application-name'")
      expect(java_opts).to include("-Dappdynamics.agent.tierName='test-tier-name'")
      expect(java_opts).to include('-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : \'.*instance_id[": ]*"\([a-z0-9]\+\)".*\')')
    end

    it 'should raise error if host-name not specified' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { } }]

      expect do
        AppDynamics.new(
            java_opts: java_opts,
            vcap_application: vcap_application,
            application: JavaBuildpack::Application.new('/tmp'),
            vcap_services: vcap_services,
            configuration: { 'tier_name' => 'test-tier-name' }
        ).release
      end.to raise_error("'host-name' credential must be set")
    end

    it 'should add port to JAVA_OPTS if specified' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name', 'port' => 'test-port' } }]

      AppDynamics.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          application: JavaBuildpack::Application.new('/tmp'),
          vcap_services: vcap_services,
          configuration: { 'tier_name' => 'test-tier-name' }
      ).release

      expect(java_opts).to include('-Dappdynamics.controller.port=test-port')
    end

    it 'should add ssl_enabled to JAVA_OPTS if specified' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name', 'ssl-enabled' => 'test-ssl-enabled' } }]

      AppDynamics.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          application: JavaBuildpack::Application.new('/tmp'),
          vcap_services: vcap_services,
          configuration: { 'tier_name' => 'test-tier-name' }
      ).release

      expect(java_opts).to include('-Dappdynamics.controller.ssl.enabled=test-ssl-enabled')
    end

    it 'should add account_name to JAVA_OPTS if specified' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name', 'account-name' => 'test-account-name' } }]

      AppDynamics.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          application: JavaBuildpack::Application.new('/tmp'),
          vcap_services: vcap_services,
          configuration: { 'tier_name' => 'test-tier-name' }
      ).release

      expect(java_opts).to include('-Dappdynamics.agent.accountName=test-account-name')
    end

    it 'should add account_access_key to JAVA_OPTS if specified' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(APP_DYNAMICS_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['app-dynamics-n/a'] = [{ 'credentials' => { 'host-name' => 'test-host-name', 'account-access-key' => 'test-account-access-key' } }]

      AppDynamics.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          application: JavaBuildpack::Application.new('/tmp'),
          vcap_services: vcap_services,
          configuration: { 'tier_name' => 'test-tier-name' }
      ).release

      expect(java_opts).to include('-Dappdynamics.agent.accountAccessKey=test-account-access-key')
    end

  end

end
