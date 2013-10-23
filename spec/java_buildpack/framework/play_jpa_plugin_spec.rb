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
require 'java_buildpack/framework/play_jpa_plugin'

module JavaBuildpack::Framework

  describe PlayJpaPlugin do

    VERSION = JavaBuildpack::Util::TokenizedVersion.new('0.7.1')

    DETAILS = [VERSION, 'test-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect Play 2.0 application' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS)

      detected = PlayJpaPlugin.new(
          app_dir: 'spec/fixtures/framework_play_jpa_plugin_play20',
          configuration: {}
      ).detect

      expect(detected).to eq('play-jpa-plugin=0.7.1')
    end

    it 'should detect staged application' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS)

      detected = PlayJpaPlugin.new(
          app_dir: 'spec/fixtures/framework_play_jpa_plugin_staged',
          configuration: {}
      ).detect

      expect(detected).to eq('play-jpa-plugin=0.7.1')
    end

    it 'should detect dist application' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS)

      detected = PlayJpaPlugin.new(
          app_dir: 'spec/fixtures/framework_play_jpa_plugin_dist',
          configuration: {}
      ).detect

      expect(detected).to eq('play-jpa-plugin=0.7.1')
    end

    it 'should not detect non-JPA application' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS)

      detected = PlayJpaPlugin.new(
          app_dir: 'spec/fixtures/container_play_2.1_dist',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should copy additional libraries to the lib directory' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-play-jpa-plugin.jar'))

        PlayJpaPlugin.new(
            app_dir: 'spec/fixtures/framework_play_jpa_plugin_dist',
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        expect(File.exists? File.join(lib_directory, 'play-jpa-plugin=0.7.1.jar')).to be_true
      end
    end

  end

end
