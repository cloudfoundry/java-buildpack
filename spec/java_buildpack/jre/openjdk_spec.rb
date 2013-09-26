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
require 'java_buildpack/jre/openjdk'

module JavaBuildpack::Jre

  describe OpenJdk do

    DETAILS_PRE_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.7.0'), 'test-uri']
    DETAILS_POST_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.8.0'), 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(opt-1 opt-2)) }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of openjdk-<version>' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        detected = OpenJdk.new(
            app_dir: '',
            java_home: '',
            java_opts: [],
            configuration: {}
        ).detect

        expect(detected).to eq('openjdk-1.7.0')
      end
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

        OpenJdk.new(
            app_dir: root,
            configuration: {},
            java_home: '',
            java_opts: []
        ).compile

        java = File.join(root, '.java', 'bin', 'java')
        expect(File.exists?(java)).to be_true
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_home = ''
        OpenJdk.new(
            app_dir: '/application-directory',
            java_home: java_home,
            java_opts: [],
            configuration: {}
        )

        expect(java_home).to eq('.java')
      end
    end

    it 'should add memory options to java_opts' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        WeightBalancingMemoryHeuristic.stub(:new).and_return(memory_heuristic)

        java_opts = []
        OpenJdk.new(
            app_dir: '/application-directory',
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include('opt-1')
        expect(java_opts).to include('opt-2')
      end
    end

    it 'adds OnOutOfMemoryError to java_opts' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include("-XX:OnOutOfMemoryError=./#{JavaBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{OpenJdk::KILLJAVA_FILE_NAME}")
      end
    end

    it 'places the killjava script (with appropriately substituted content) in the diagnostics directory' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

        java_opts = []
        OpenJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).compile

        killjava_content = File.read(File.join(JavaBuildpack::Diagnostics.get_diagnostic_directory(root), OpenJdk::KILLJAVA_FILE_NAME))
        expect(killjava_content).to include("#{JavaBuildpack::Diagnostics::LOG_FILE_NAME}")
      end
    end

    it 'adds java.io.tmpdir to java_opts' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
            app_dir: root,
            java_home: '',
            java_opts: java_opts,
            configuration: {}
        ).release

        expect(java_opts).to include('-Djava.io.tmpdir=$TMPDIR')
      end
    end

  end

end
