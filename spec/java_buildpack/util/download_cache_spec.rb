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
require 'diagnostics_helper'
require 'fileutils'
require 'java_buildpack/util/download_cache'
require 'yaml'

module JavaBuildpack::Util

  describe DownloadCache do
    include_context 'application_helper'
    include_context 'diagnostics_helper'

    let(:download_cache) { DownloadCache.new(app_dir) }

    let(:trigger) { download_cache.get('http://foo-uri/') {} }

    before do |example|
      JavaBuildpack::Util::DownloadCache.clear_internet_availability
      DownloadCache.store_internet_availability true if example.metadata[:skip_availability_check]
    end

    before do
      stub_request(:get, 'http://foo-uri/').with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '', headers: {})
    end

    it 'should download (during internet availability checking) from a uri if the cached file does not exist' do
      stub_request(:get, 'http://foo-uri/')
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      trigger

      expect_complete_cache
    end

    it 'should download (after internet availability checking) from a uri if the cached file does not exist',
       :skip_availability_check do

      stub_request(:get, 'http://foo-uri/')
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      download_cache.get('http://foo-uri/') {}

      expect_complete_cache
    end

    it 'should raise error if download cannot be completed' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      expect { trigger }.to raise_error
    end

    it 'should not raise error if download cannot be completed but retrying succeeds' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError).then
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      trigger

      expect_complete_cache
    end

    it 'should download from a uri if the cached file exists and etag exists',
       :skip_availability_check do

      stub_request(:get, 'http://foo-uri/').with(headers: { 'If-None-Match' => 'foo-etag' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'

      trigger

      expect_complete_cache
    end

    it 'should use cached copy if update cannot be completed' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'

      trigger
    end

    it 'should download from a uri if the cached file exists and last modified exists',
       :skip_availability_check do

      stub_request(:get, 'http://foo-uri/').with(headers: { 'If-Modified-Since' => 'foo-last-modified' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_complete_cache
    end

    it 'should download from a uri if the cached file exists, etag exists, and last modified exists' do
      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'If-None-Match' => 'foo-etag', 'If-Modified-Since' => 'foo-last-modified' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_complete_cache
    end

    it 'should download from a uri if the cached file does not exist, etag exists, and last modified exists' do
      stub_request(:get, 'http://foo-uri/')
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      touch app_dir, 'etag', 'foo-etag'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_complete_cache
    end

    it 'should not download from a uri if the cached file exists and the etag and last modified do not exist' do
      touch app_dir, 'cached', 'foo-cached'

      trigger

      expect_file_content 'cached', 'foo-cached'
    end

    it 'should not overwrite existing information if 304 is received' do
      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'If-None-Match' => 'foo-etag', 'If-Modified-Since' => 'foo-last-modified' })
      .to_return(status: 304, body: 'bar-cached', headers: { Etag: 'bar-etag', 'Last-Modified' => 'bar-last-modified' })

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_complete_cache
    end

    it 'should overwrite existing information if 304 is not received',
       :skip_availability_check do

      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'If-None-Match' => 'foo-etag', 'If-Modified-Since' => 'foo-last-modified' })
      .to_return(status: 200, body: 'bar-cached', headers: { Etag: 'bar-etag', 'Last-Modified' => 'bar-last-modified' })

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_file_content 'cached', 'bar-cached'
      expect_file_content 'etag', 'bar-etag'
      expect_file_content 'last_modified', 'bar-last-modified'
    end

    it 'should not overwrite existing information if the update request fails',
       :skip_availability_check do

      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'If-None-Match' => 'foo-etag', 'If-Modified-Since' => 'foo-last-modified' })
      .to_raise(SocketError)

      touch app_dir, 'cached', 'foo-cached'
      touch app_dir, 'etag', 'foo-etag'
      touch app_dir, 'last_modified', 'foo-last-modified'

      trigger

      expect_complete_cache

      expect(stderr.string).to match('Unable to update from http://foo-uri/ due to Exception from WebMock. Using cached version.')
    end

    it 'should pass read-only file to block' do
      stub_request(:get, 'http://foo-uri/')
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      download_cache.get('http://foo-uri/') do |file|
        expect(file.read).to eq('foo-cached')
        expect { file.write('bar') }.to raise_error
      end
    end

    it 'should delete the cached file if it exists' do
      expect_file_deleted 'cached'
    end

    it 'should delete the etag file if it exists' do
      expect_file_deleted 'etag'
    end

    it 'should delete the last_modified file if it exists' do
      expect_file_deleted 'last_modified'
    end

    it 'should delete the lock file if it exists' do
      expect_file_deleted 'lock'
    end

    context do
      include_context 'buildpack_cache_helper'

      it 'should use the buildpack cache if the download cannot be completed' do
        stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

        touch java_buildpack_cache_dir, 'cached', 'foo-stashed'

        download_cache.get('http://foo-uri/') do |file|
          expect(file.read).to eq('foo-stashed')
        end
      end

      it 'should not use the buildpack cache if the download cannot be completed but a retry succeeds' do
        stub_request(:get, 'http://foo-uri/').to_raise(SocketError).then
        .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

        touch java_buildpack_cache_dir, 'cached', 'foo-stashed'

        download_cache.get('http://foo-uri/') do |file|
          expect(file.read).to eq('foo-cached')
        end
      end

      it 'should use the buildpack cache if the download cannot be completed because Errno::ENETUNREACH is raised' do
        stub_request(:get, 'http://foo-uri/').to_raise(Errno::ENETUNREACH)

        touch java_buildpack_cache_dir, 'cached', 'foo-stashed'

        download_cache.get('http://foo-uri/') do |file|
          expect(file.read).to eq('foo-stashed')
        end
      end

      it 'should use the buildpack cache if the cache configuration disables remote downloads' do
        allow(YAML).to receive(:load_file).with(File.expand_path('config/cache.yml'))
                       .and_return('remote_downloads' => 'disabled')

        touch java_buildpack_cache_dir, 'cached', 'foo-stashed'

        download_cache.get('http://foo-uri/') do |file|
          expect(file.read).to eq('foo-stashed')
        end
      end

      it 'should raise an error if the cache configuration remote downloads setting is invalid' do
        allow(YAML).to receive(:load_file).with(File.expand_path('config/cache.yml'))
                       .and_return('remote_downloads' => 'junk')

        touch java_buildpack_cache_dir, 'cached', 'foo-stashed'

        expect { trigger }.to raise_error /Invalid remote_downloads property in cache configuration:/
      end

      it 'should raise error if download cannot be completed and buildpack cache does not contain the file' do
        stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

        expect { trigger }.to raise_error
      end
    end

    it 'should fail if a download attempt fails' do
      stub_request(:get, 'http://foo-uri/')
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

      stub_request(:get, 'http://bar-uri/').to_raise(SocketError)

      trigger

      expect { download_cache.get('http://bar-uri/') {} }.to raise_error %r(Unable to download from http://bar-uri/)
    end

    def cache_file(root, extension)
      root + "http:%2F%2Ffoo-uri%2F.#{extension}"
    end

    def expect_complete_cache
      expect_file_content 'cached', 'foo-cached'
      expect_file_content 'etag', 'foo-etag'
      expect_file_content 'last_modified', 'foo-last-modified'
    end

    def expect_file_content(extension, content = '')
      file = cache_file app_dir, extension
      expect(file).to exist
      expect(file.read).to eq(content)
    end

    def expect_file_deleted(extension)
      file = touch app_dir, extension
      expect(file).to exist

      download_cache.evict('http://foo-uri/')

      expect(file).not_to exist
    end

    def touch(root, extension, content = '')
      file = cache_file root, extension
      FileUtils.mkdir_p file.dirname
      File.open(file, 'w') { |f| f.write(content) }

      file
    end
  end

end
