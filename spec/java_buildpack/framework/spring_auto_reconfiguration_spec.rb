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
require 'java_buildpack/framework/spring_auto_reconfiguration'

module JavaBuildpack::Framework

  describe SpringAutoReconfiguration do

    SPRING_AUTO_RECONFIGURATION_VERSION = JavaBuildpack::Util::TokenizedVersion.new('0.6.8')

    SPRING_AUTO_RECONFIGURATION_DETAILS = [SPRING_AUTO_RECONFIGURATION_VERSION, 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:web_xml_modifier) { double('WebXmlModifier') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with Spring JAR' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
          app_dir: 'spec/fixtures/framework_auto_reconfiguration_servlet_3',
          configuration: {}
      ).detect

      expect(detected).to eq('spring-auto-reconfiguration=0.6.8')
    end

    it 'should detect with Spring JAR which has a long name' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)

      detected = SpringAutoReconfiguration.new(
          app_dir: 'spec/fixtures/framework_auto_reconfiguration_long_spring_jar_name',
          configuration: {}
      ).detect

      expect(detected).to eq('spring-auto-reconfiguration=0.6.8')
    end

    it 'should not detect without Spring JAR' do
      detected = SpringAutoReconfiguration.new(
          app_dir: 'spec/fixtures/framework_none',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should copy additional libraries to the lib directory' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))

        SpringAutoReconfiguration.new(
            app_dir: 'spec/fixtures/framework_auto_reconfiguration_servlet_3',
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        expect(File.exists? File.join(lib_directory, 'spring-auto-reconfiguration-0.6.8.jar')).to be_true
      end
    end

    it 'should update web.xml if it exists' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory
        FileUtils.cp_r 'spec/fixtures/framework_auto_reconfiguration_servlet_2/.', root
        web_xml = File.join root, 'WEB-INF', 'web.xml'

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(SPRING_AUTO_RECONFIGURATION_DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-auto-reconfiguration.jar'))
        JavaBuildpack::Framework::WebXmlModifier.stub(:new).and_return(web_xml_modifier)
        web_xml_modifier.should_receive(:augment_root_context)
        web_xml_modifier.should_receive(:augment_servlet_contexts)
        web_xml_modifier.stub(:to_s).and_return('Test Content')

        SpringAutoReconfiguration.new(
            app_dir: root,
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        File.open(web_xml) { |file| expect(file.read).to eq('Test Content') }
      end
    end

  end

end
