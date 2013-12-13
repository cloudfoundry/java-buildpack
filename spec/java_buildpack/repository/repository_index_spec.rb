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
require 'buildpack_cache_helper'
require 'logging_helper'
require 'fileutils'
require 'java_buildpack/repository/repository_index'
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/cache/download_cache'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Repository::RepositoryIndex do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:application_cache) { double('ApplicationCache') }

  before do
    allow(JavaBuildpack::Util::Cache::DownloadCache).to receive(:new).and_return(application_cache)
  end

  it 'should load index' do
    allow(application_cache).to receive(:get).with(%r(/test-uri/index\.yml))
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)
    allow(JavaBuildpack::Repository::VersionResolver).to receive(:resolve).with('test-version', %w(resolved-version))
                                                         .and_return('resolved-version')

    repository_index = described_class.new('{platform}/{architecture}/test-uri')

    expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri))
  end

  it 'should cope with trailing slash in repository URI' do
    allow(application_cache).to receive(:get).with(%r(/test-uri/index\.yml))
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)
    allow(JavaBuildpack::Repository::VersionResolver).to receive(:resolve).with('test-version', %w(resolved-version))
                                                         .and_return('resolved-version')

    repository_index = described_class.new('{platform}/{architecture}/test-uri/')

    expect(repository_index.find_item('test-version')).to eq(%w(resolved-version resolved-uri))
  end

  it 'should substitute the default repository root' do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('repository')
                                                      .and_return('default_repository_root' => 'http://default-repository-root/')
    expect(application_cache).to receive(:get).with('http://default-repository-root/test-uri/index.yml')
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)

    described_class.new('{default.repository.root}/test-uri')
  end

  context do
    include_context 'buildpack_cache_helper'

    it 'should use the read-only buildpack cache when index.yaml cannot be downloaded because the internet is not available' do
      stub_request(:get, 'http://foo.com/index.yml').to_raise(SocketError)
      allow(JavaBuildpack::Util::Cache::DownloadCache).to receive(:new).and_call_original

      FileUtils.mkdir_p java_buildpack_cache_dir
      FileUtils.cp 'spec/fixtures/stashed_repository_index.yml', java_buildpack_cache_dir + 'http:%2F%2Ffoo.com%2Findex.yml.cached'

      version, uri = described_class.new('http://foo.com').find_item(JavaBuildpack::Util::TokenizedVersion.new('1.0.+'))

      expect(version).to eq(JavaBuildpack::Util::TokenizedVersion.new('1.0.1'))
      expect(uri).to eq('http://foo.com/test.txt')
    end
  end

  it 'should handle Centos correctly' do
    allow(Pathname).to receive(:new).and_call_original
    redhat_release = double('redhat-release')
    allow(Pathname).to receive(:new).with('/etc/redhat-release').and_return(redhat_release)

    allow_any_instance_of(described_class).to receive(:`).with('uname -s').and_return('Linux')
    allow_any_instance_of(described_class).to receive(:`).with('uname -m').and_return('x86_64')
    allow_any_instance_of(described_class).to receive(:`).with('which lsb_release 2> /dev/null').and_return('')
    allow(redhat_release).to receive(:exist?).and_return(true)
    allow(redhat_release).to receive(:read).and_return('CentOS release 6.4 (Final)')
    allow(application_cache).to receive(:get).with('centos6/x86_64/test-uri/index.yml')
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)

    described_class.new('{platform}/{architecture}/test-uri')

    expect(application_cache).to have_received(:get).with %r(centos6/x86_64/test-uri/index\.yml)
  end

  it 'should handle Mac OS X correctly' do
    allow_any_instance_of(described_class).to receive(:`).with('uname -s').and_return('Darwin')
    allow_any_instance_of(described_class).to receive(:`).with('uname -m').and_return('x86_64')
    allow(application_cache).to receive(:get).with('mountainlion/x86_64/test-uri/index.yml')
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)

    described_class.new('{platform}/{architecture}/test-uri')

    expect(application_cache).to have_received(:get).with %r(mountainlion/x86_64/test-uri/index\.yml)
  end

  it 'should handle Ubuntu correctly' do
    allow_any_instance_of(described_class).to receive(:`).with('uname -s').and_return('Linux')
    allow_any_instance_of(described_class).to receive(:`).with('uname -m').and_return('x86_64')
    allow_any_instance_of(described_class).to receive(:`).with('which lsb_release 2> /dev/null').and_return('/usr/bin/lsb_release')
    allow_any_instance_of(described_class).to receive(:`).with('lsb_release -cs').and_return('precise')
    allow(application_cache).to receive(:get).with('precise/x86_64/test-uri/index.yml')
                                .and_yield(Pathname.new('spec/fixtures/test-index.yml').open)

    described_class.new('{platform}/{architecture}/test-uri')

    expect(application_cache).to have_received(:get).with %r(precise/x86_64/test-uri/index\.yml)
  end

  it 'should handle unknown OS correctly' do
    allow_any_instance_of(File).to receive(:exists?).with('/etc/redhat-release').and_return(false)
    allow_any_instance_of(described_class).to receive(:`).with('uname -s').and_return('Linux')
    allow_any_instance_of(described_class).to receive(:`).with('which lsb_release 2> /dev/null').and_return('')

    expect { described_class.new('{platform}/{architecture}/test-uri') }
    .to raise_error('Unable to determine platform')
  end

end
