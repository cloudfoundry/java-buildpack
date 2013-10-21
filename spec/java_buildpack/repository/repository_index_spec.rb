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

require 'java_buildpack/repository/repository_index'
require 'spec_helper'
require 'java_buildpack/util/download_cache'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack::Repository

  describe RepositoryIndex do

    let(:application_cache) { double('ApplicationCache') }

    it 'should load index' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with(%r(/test-uri/index\.yml))
      .and_yield(File.open('spec/fixtures/test-index.yml'))
      VersionResolver.stub(:resolve).with('test-version', %w(resolved-version)).and_return('resolved-version')

      repository_index = RepositoryIndex.new('{platform}/{architecture}/test-uri')
      expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri))
    end

    it 'should use the read-only buildpack cache when index.yaml cannot be downloaded because the internet is not available' do
      stub_request(:get, 'http://foo.com/index.yml').to_raise(SocketError)

      Dir.mktmpdir do |buildpack_cache|
        java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
        FileUtils.mkdir_p java_buildpack_cache
        FileUtils.cp('spec/fixtures/stashed_repository_index.yml', File.join(java_buildpack_cache, 'http:%2F%2Ffoo.com%2Findex.yml.cached'))
        with_buildpack_cache(buildpack_cache) do
          repository_index = RepositoryIndex.new('http://foo.com')
          version, uri = repository_index.find_item(JavaBuildpack::Util::TokenizedVersion.new('1.0.+'))
          expect(version).to eq(JavaBuildpack::Util::TokenizedVersion.new('1.0.1'))
          expect(uri).to eq('http://foo.com/test.txt')
        end
      end
    end

    it 'should handle Centos correctly' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      RepositoryIndex.any_instance.stub(:`).with('uname -s').and_return('Linux')
      RepositoryIndex.any_instance.stub(:`).with('uname -m').and_return('x86_64')
      RepositoryIndex.any_instance.stub(:`).with('which lsb_release 2> /dev/null').and_return('')
      File.stub(:exists?).with('/etc/redhat-release').and_return(true)
      File.stub(:open).and_call_original
      File.stub(:open).with('/etc/redhat-release', 'r').and_yield(File.new('spec/fixtures/redhat-release'))
      application_cache.stub(:get).with('centos6/x86_64/test-uri/index.yml').and_yield(File.open('spec/fixtures/test-index.yml'))
      RepositoryIndex.new('{platform}/{architecture}/test-uri')
      expect(application_cache).to have_received(:get).with(%r(centos6/x86_64/test-uri/index\.yml))
    end

    it 'should handle Mac OS X correctly' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      RepositoryIndex.any_instance.stub(:`).with('uname -s').and_return('Darwin')
      RepositoryIndex.any_instance.stub(:`).with('uname -m').and_return('x86_64')
      application_cache.stub(:get).with('mountainlion/x86_64/test-uri/index.yml').and_yield(File.open('spec/fixtures/test-index.yml'))
      RepositoryIndex.new('{platform}/{architecture}/test-uri')
      expect(application_cache).to have_received(:get).with(%r(mountainlion/x86_64/test-uri/index\.yml))
    end

    it 'should handle Ubuntu correctly' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      RepositoryIndex.any_instance.stub(:`).with('uname -s').and_return('Linux')
      RepositoryIndex.any_instance.stub(:`).with('uname -m').and_return('x86_64')
      RepositoryIndex.any_instance.stub(:`).with('which lsb_release 2> /dev/null').and_return('/usr/bin/lsb_release')
      RepositoryIndex.any_instance.stub(:`).with('lsb_release -cs').and_return('precise')
      application_cache.stub(:get).with('precise/x86_64/test-uri/index.yml').and_yield(File.open('spec/fixtures/test-index.yml'))
      RepositoryIndex.new('{platform}/{architecture}/test-uri')
      expect(application_cache).to have_received(:get).with(%r(precise/x86_64/test-uri/index\.yml))
    end

    it 'should handle unknown OS correctly' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      File.stub(:exists?).with('/etc/redhat-release').and_return(false)
      RepositoryIndex.any_instance.stub(:`).with('uname -s').and_return('Linux')
      RepositoryIndex.any_instance.stub(:`).with('which lsb_release 2> /dev/null').and_return('')

      expect { RepositoryIndex.new('{platform}/{architecture}/test-uri') }.to raise_error('Unable to determine platform')
    end

    def with_buildpack_cache(directory)
      previous_value, ENV['BUILDPACK_CACHE'] = ENV['BUILDPACK_CACHE'], directory
      yield
    ensure
      ENV['BUILDPACK_CACHE'] = previous_value
    end

  end

end
