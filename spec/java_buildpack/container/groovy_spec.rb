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
require 'java_buildpack/container/groovy'

module JavaBuildpack::Container

  describe Groovy do

    GROOVY_VERSION = JavaBuildpack::Util::TokenizedVersion.new('2.1.5')

    GROOVY_DETAILS = [GROOVY_VERSION, 'test-groovy-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should not detect a non-Groovy project' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
      .and_return(GROOVY_DETAILS)
      detected = Groovy.new(
          app_dir: 'spec/fixtures/container_main',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect a .groovy directory' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
      .and_return(GROOVY_DETAILS)
      detected = Groovy.new(
          app_dir: 'spec/fixtures/dot_groovy',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should detect a Groovy file with a main() method' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
      .and_return(GROOVY_DETAILS)
      detected = Groovy.new(
          app_dir: 'spec/fixtures/container_groovy_main_method',
          configuration: {}
      ).detect

      expect(detected).to include('groovy-2.1.5')
    end

    it 'should detect a Groovy file with non-POGO' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
      .and_return(GROOVY_DETAILS)
      detected = Groovy.new(
          app_dir: 'spec/fixtures/container_groovy_non_pogo',
          configuration: {}
      ).detect

      expect(detected).to include('groovy-2.1.5')
    end

    it 'should detect a Groovy file with #!' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
      .and_return(GROOVY_DETAILS)
      detected = Groovy.new(
          app_dir: 'spec/fixtures/container_groovy_shebang',
          configuration: {}
      ).detect

      expect(detected).to include('groovy-2.1.5')
    end

    it 'should fail when a malformed version is detected' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JavaBuildpack::Util::TokenizedVersion.new('2.1.5_10')) if block }
      .and_return(GROOVY_DETAILS)
      expect do
        Groovy.new(
            app_dir: 'spec/fixtures/container_groovy_main_method',
            configuration: {}
        ).detect
      end.to raise_error(/Malformed\ version/)
    end

    it 'should extract Groovy from a ZIP' do
      Dir.mktmpdir do |root|
        Dir['spec/fixtures/container_groovy_main_method/*'].each { |file| system "cp -r #{file} #{root}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
        .and_return(GROOVY_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-groovy-uri').and_yield(File.open('spec/fixtures/stub-groovy.zip'))

        Groovy.new(
            app_dir: root,
            configuration: {}
        ).compile

        groovy = File.join root, '.groovy', 'bin', 'groovy'
        expect(File.exists?(groovy)).to be_true
      end
    end

    it 'should return command' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{lib_directory}" }
        Dir['spec/fixtures/container_groovy_main_method/*'].each { |file| system "cp -r #{file} #{root}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(GROOVY_VERSION) if block }
        .and_return(GROOVY_DETAILS)

        command = Groovy.new(
            app_dir: root,
            java_home: 'test-java-home',
            java_opts: %w(test-opt-2 test-opt-1),
            lib_directory: lib_directory,
            configuration: {}
        ).release

        expect(command).to eq('JAVA_HOME=test-java-home JAVA_OPTS="test-opt-1 test-opt-2" .groovy/bin/groovy -cp .lib/test-jar-1.jar:.lib/test-jar-2.jar Application.groovy Alpha.groovy directory/Beta.groovy')
      end
    end

  end

end
