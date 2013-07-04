# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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
require 'java_buildpack/framework/spring_auto_reconfiguration'

module JavaBuildpack::Framework

  describe SpringAutoReconfiguration do

    AUTO_RECONFIGURATION_VERSION = JavaBuildpack::Util::TokenizedVersion.new('0.6.8')

    AUTO_RECONFIGURATION_DETAILS = [AUTO_RECONFIGURATION_VERSION, 'test-auto-reconfiguration-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with Spring JAR' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
        :app_dir => 'spec/fixtures/framework_spring_auto_reconfiguration',
        :configuration => {}).detect

      expect(detected).to eq('spring-auto-reconfiguration-0.6.8')
    end

    it 'should not detect without Spring JAR' do
      detected = SpringAutoReconfiguration.new(
        :app_dir => 'spec/fixtures/framework_none',
        :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should copy additional libraries to the lib directory' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        FileUtils.mkdir_p lib_directory

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(AUTO_RECONFIGURATION_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-auto-reconfiguration-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))

        SpringAutoReconfiguration.new(
          :app_dir => 'spec/fixtures/framework_spring_auto_reconfiguration',
          :lib_directory => lib_directory,
          :configuration => {}).compile

        expect(File.exists? File.join(lib_directory, 'spring-auto-reconfiguration.jar')).to be_true
      end
    end

  end

end
