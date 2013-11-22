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
require 'application_helper'
require 'diagnostics_helper'
require 'fileutils'
require 'java_buildpack/repository/repository_index'
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/download_cache'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack::Repository

  describe RepositoryIndex do
    include_context 'application_helper'
    include_context 'diagnostics_helper'

    let(:application_cache) { double('ApplicationCache') }

    before do
      allow(JavaBuildpack::Util::DownloadCache).to receive(:new).and_return(application_cache)
    end

    it 'should load index' do
      allow(application_cache).to receive(:get).with(%r(/test-uri/index\.yml))
                                  .and_yield(File.open('spec/fixtures/test-index.yml'))
      allow(VersionResolver).to receive(:resolve).with('test-version', %w(resolved-version))
                                .and_return('resolved-version')

      repository_index = RepositoryIndex.new('{platform}/{architecture}/test-uri')

      expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri))
    end

    it 'should cope with trailing slash in repository URI' do
      allow(application_cache).to receive(:get).with(%r(/test-uri/index\.yml))
                                  .and_yield(File.open('spec/fixtures/test-index.yml'))
      allow(VersionResolver).to receive(:resolve).with('test-version', %w(resolved-version))
                                .and_return('resolved-version')

      repository_index = RepositoryIndex.new('{platform}/{architecture}/test-uri/')

      expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri))
    end

    it 'should use the read-only buildpack cache when index.yaml cannot be downloaded because the internet is not available' do
      stub_request(:get, 'http://foo.com/index.yml').to_raise(SocketError)
      allow(JavaBuildpack::Util::DownloadCache).to receive(:new).and_call_original

      java_buildpack_cache = app_dir + 'java-buildpack'
      FileUtils.mkdir_p java_buildpack_cache
      FileUtils.cp 'spec/fixtures/stashed_repository_index.yml', java_buildpack_cache + 'http:%2F%2Ffoo.com%2Findex.yml.cached'

      version, uri = RepositoryIndex.new('http://foo.com').find_item(JavaBuildpack::Util::TokenizedVersion.new('1.0.+'))

      expect(version).to eq(JavaBuildpack::Util::TokenizedVersion.new('1.0.1'))
      expect(uri).to eq('http://foo.com/test.txt')
    end

    it 'should handle Centos correctly' do
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -s').and_return('Linux')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -m').and_return('x86_64')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('which lsb_release 2> /dev/null').and_return('')
      allow(File).to receive(:exists?).with('/etc/redhat-release').and_return(true)
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with('/etc/redhat-release', 'r').and_yield(File.new('spec/fixtures/redhat-release'))
      allow(application_cache).to receive(:get).with('centos6/x86_64/test-uri/index.yml')
                                  .and_yield(File.open('spec/fixtures/test-index.yml'))

      RepositoryIndex.new('{platform}/{architecture}/test-uri')

      expect(application_cache).to have_received(:get).with %r(centos6/x86_64/test-uri/index\.yml)
    end

    it 'should handle Mac OS X correctly' do
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -s').and_return('Darwin')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -m').and_return('x86_64')
      allow(application_cache).to receive(:get).with('mountainlion/x86_64/test-uri/index.yml')
                                  .and_yield(File.open('spec/fixtures/test-index.yml'))

      RepositoryIndex.new('{platform}/{architecture}/test-uri')

      expect(application_cache).to have_received(:get).with %r(mountainlion/x86_64/test-uri/index\.yml)
    end

    it 'should handle Ubuntu correctly' do
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -s').and_return('Linux')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -m').and_return('x86_64')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('which lsb_release 2> /dev/null').and_return('/usr/bin/lsb_release')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('lsb_release -cs').and_return('precise')
      allow(application_cache).to receive(:get).with('precise/x86_64/test-uri/index.yml')
                                  .and_yield(File.open('spec/fixtures/test-index.yml'))

      RepositoryIndex.new('{platform}/{architecture}/test-uri')

      expect(application_cache).to have_received(:get).with %r(precise/x86_64/test-uri/index\.yml)
    end

    it 'should handle unknown OS correctly' do
      allow_any_instance_of(File).to receive(:exists?).with('/etc/redhat-release').and_return(false)
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('uname -s').and_return('Linux')
      allow_any_instance_of(RepositoryIndex).to receive(:`).with('which lsb_release 2> /dev/null').and_return('')

      expect { RepositoryIndex.new('{platform}/{architecture}/test-uri') }
      .to raise_error('Unable to determine platform')
    end
  end

end
