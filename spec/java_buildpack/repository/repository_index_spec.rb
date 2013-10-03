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

    it 'should handle Mac OS X correctly' do
      with_host('darwin12.3.0', 'x86_64') do
        JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
        RepositoryIndex.any_instance.stub(:`).with('sw_vers -productVersion').and_return('10.8.4')
        application_cache.stub(:get).with('mountainlion/x86_64/test-uri/index.yml').and_yield(File.open('spec/fixtures/test-index.yml'))
        RepositoryIndex.new('{platform}/{architecture}/test-uri')
        expect(application_cache).to have_received(:get).with(%r(mountainlion/x86_64/test-uri/index\.yml))
      end
    end

    it 'should handle incorrect Mac OS X version correctly' do
      with_host('darwin12.3.0', 'x86_64') do
        JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
        RepositoryIndex.any_instance.stub(:`).with('sw_vers -productVersion').and_return('10.7.1')
        expect { RepositoryIndex.new('{platform}/{architecture}/test-uri') }.to raise_error(/Unsupported OS X version/)
      end
    end

    it 'should handle Linux correctly' do
      with_host('linux-gnu', 'x86_64') do
        JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
        RepositoryIndex.any_instance.stub(:`).with('lsb_release -cs').and_return('precise')
        application_cache.stub(:get).with('precise/x86_64/test-uri/index.yml').and_yield(File.open('spec/fixtures/test-index.yml'))
        RepositoryIndex.new('{platform}/{architecture}/test-uri')
        expect(application_cache).to have_received(:get).with(%r(precise/x86_64/test-uri/index\.yml))
      end
    end

    def with_host(host_os, host_cpu)
      previous_host_os, RbConfig::CONFIG['host_os'] = RbConfig::CONFIG['host_os'], host_os
      previous_host_cpu, RbConfig::CONFIG['host_cpu'] = RbConfig::CONFIG['host_cpu'], host_cpu
      yield
    ensure
      RbConfig::CONFIG['host_os'] = previous_host_os
      RbConfig::CONFIG['host_cpu'] = previous_host_cpu
    end

    def with_buildpack_cache(directory)
      previous_value, ENV['BUILDPACK_CACHE'] = ENV['BUILDPACK_CACHE'], directory
      yield
    ensure
      ENV['BUILDPACK_CACHE'] = previous_value
    end

    def touch(root, extension, content = '')
      file = File.join(root, "http:%2F%2Ffoo.com%2Ftest.txt%2F.#{extension}")
      File.open(file, 'w') do |f|
        f.write(content)
        f.fsync
      end
      file
    end

  end

end
