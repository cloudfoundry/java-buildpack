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
require 'java_buildpack/jre/openjdk'
require 'tmpdir'

module JavaBuildpack::Jre

  describe OpenJdk do

    DETAILS_PRE_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.7.0'), 'test-uri']
    DETAILS_POST_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.8.0'), 'test-uri']

    let(:application_cache) { double('ApplicationCache') }
    let(:memory_heuristic) { double('MemoryHeuristic', :resolve => ['opt-1', 'opt-2']) }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of openjdk-<version>' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        detected = OpenJdk.new(
            :app_dir => '',
            :java_home => '',
            :java_opts => [],
            :configuration => {},
            :diagnostics => {:directory => root}
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
            :app_dir => root,
            :configuration => {},
            :java_home => '',
            :java_opts => [],
            :diagnostics => {:directory => root}
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
            :app_dir => '/application-directory',
            :java_home => java_home,
            :java_opts => [],
            :configuration => {},
            :diagnostics => {:directory => root}
        )

        expect(java_home).to eq('.java')
      end
    end

    it 'should fail when ConfiguredItem.find_item fails' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise('test error')
        expect { OpenJdk.new(
            :app_dir => '',
            :java_home => '',
            :java_opts => [],
            :configuration => {},
            :diagnostics => {:directory => root}
        ).detect }.to raise_error(/OpenJDK\ JRE\ error:\ test\ error/)
      end
    end

    it 'should add memory options to java_opts' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        MemoryHeuristicsOpenJDKPre8.stub(:new).and_return(memory_heuristic)

        java_opts = []
        OpenJdk.new(
            :app_dir => '/application-directory',
            :java_home => '',
            :java_opts => java_opts,
            :configuration => {},
            :diagnostics => {:directory => root}
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
            :app_dir => '',
            :java_home => '',
            :java_opts => java_opts,
            :configuration => {},
            :diagnostics => {:directory => root}
        ).release

        expect(java_opts.join(' ')).to match(/-XX:OnOutOfMemoryError=\$HOME\/buildpack-diagnostics\/killjava/)
      end
    end

  end

end
