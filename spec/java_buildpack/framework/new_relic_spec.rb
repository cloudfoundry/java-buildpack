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
require 'java_buildpack/framework/new_relic'

module JavaBuildpack::Framework

  describe NewRelic do

    NEW_RELIC_VERSION = JavaBuildpack::Util::TokenizedVersion.new('2.21.2')

    NEW_RELIC_DETAILS = [NEW_RELIC_VERSION, 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:java_opts) { [] }
    let(:vcap_application) { {} }
    let(:vcap_services) { {} }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with newrelic-n/a service' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
      vcap_services['newrelic-n/a'] = [{ 'credentials' => { 'licenseKey' => 'test-license-key' } }]

      detected = NewRelic.new(
          vcap_services: vcap_services
      ).detect

      expect(detected).to eq('new-relic-2.21.2')
    end

    it 'should not detect without newrelic-n/a service' do
      detected = NewRelic.new(
          vcap_services: vcap_services
      ).detect

      expect(detected).to be_nil
    end

    it 'should fail with multiple newrelic-n/a services' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
      vcap_services['newrelic-n/a'] = [
          { 'credentials' => { 'licenseKey' => 'test-license-key' } },
          { 'credentials' => { 'licenseKey' => 'test-license-key' } }
      ]

      expect do
        NewRelic.new(
            vcap_services: vcap_services
        ).detect
      end.to raise_error
    end

    it 'should fail with zero newrelic-n/a services' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
      vcap_services['newrelic-n/a'] = []

      expect do
        NewRelic.new(
            vcap_services: vcap_services
        ).detect
      end.to raise_error
    end

    it 'should copy additional libraries to the lib directory' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-new-relic.jar'))
        vcap_services['newrelic-n/a'] = [{ 'credentials' => { 'licenseKey' => 'test-license-key' } }]

        NewRelic.new(
            app_dir: root,
            vcap_services: vcap_services
        ).compile

        expect(File.exists? File.join(root, '.new-relic', 'new-relic-2.21.2.jar')).to be_true
      end
    end

    it 'should copy resources' do
      Dir.mktmpdir do |root|

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-new-relic.jar'))
        vcap_services['newrelic-n/a'] = [{ 'credentials' => { 'licenseKey' => 'test-license-key' } }]

        NewRelic.new(
            app_dir: root,
            vcap_services: vcap_services
        ).compile

        expect(File.exists? File.join(root, '.new-relic', 'newrelic.yml')).to be_true
      end
    end

    it 'should update JAVA_OPTS' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(NEW_RELIC_DETAILS)
      vcap_application['application_name'] = 'test-application-name'
      vcap_services['newrelic-n/a'] = [{ 'credentials' => { 'licenseKey' => 'test-license-key' } }]

      NewRelic.new(
          java_opts: java_opts,
          vcap_application: vcap_application,
          vcap_services: vcap_services
      ).release

      expect(java_opts).to include('-javaagent:.new-relic/new-relic-2.21.2.jar')
      expect(java_opts).to include('-Dnewrelic.home=.new-relic')
      expect(java_opts).to include('-Dnewrelic.config.license_key=test-license-key')
      expect(java_opts).to include("-Dnewrelic.config.app_name='test-application-name'")
      expect(java_opts).to include('-Dnewrelic.config.log_file_path=.new-relic/logs')
    end

  end

end
