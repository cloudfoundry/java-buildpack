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

require 'fileutils'
require 'spec_helper'
require 'java_buildpack/util/download_cache'

module JavaBuildpack::Util

  describe DownloadCache do

    def suppress_internet_availability_check
      DownloadCache.send :store_internet_availability, true
    end

    before do
      JavaBuildpack::Diagnostics::LoggerFactory.send :close
      $stderr = StringIO.new
      tmpdir = Dir.tmpdir
      diagnostics_directory = File.join(tmpdir, JavaBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
      FileUtils.rm_rf diagnostics_directory
      JavaBuildpack::Diagnostics::LoggerFactory.create_logger tmpdir
      $stdout = StringIO.new

      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '', headers: { })

      DownloadCache.class_variable_set :@@internet_checked, false
    end

    after do
      DownloadCache.class_variable_set :@@internet_checked, false
    end

    it 'should download (during internet availability checking) from a uri if the cached file does not exist' do
      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should download (after internet availability checking) from a uri if the cached file does not exist' do
      suppress_internet_availability_check

      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should raise error if download cannot be completed' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      Dir.mktmpdir do |root|
        expect { DownloadCache.new(root).get('http://foo-uri/') { } }.to raise_error
      end
    end

    it 'should download from a uri if the cached file exists and etag exists' do
      suppress_internet_availability_check

      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-None-Match' => 'foo-etag'
          }
      ).to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should use cached copy if update cannot be completed' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'

        DownloadCache.new(root).get('http://foo-uri/') { }
      end
    end

    it 'should download from a uri if the cached file exists and last modified exists' do
      suppress_internet_availability_check

      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-Modified-Since' => 'foo-last-modified'
          }
      ).to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should download from a uri if the cached file exists, etag exists, and last modified exists' do
      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-None-Match' => 'foo-etag',
              'If-Modified-Since' => 'foo-last-modified'
          }
      ).to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should download from a uri if the cached file does not exist, etag exists, and last modified exists' do
      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'etag', 'foo-etag'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should not download from a uri if the cached file exists and the etag and last modified do not exist' do
      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
      end
    end

    it 'should not overwrite existing information if 304 is received' do
      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-None-Match' => 'foo-etag',
              'If-Modified-Since' => 'foo-last-modified'
          }
      ).to_return(
          status: 304,
          body: 'bar-cached',
          headers: {
              Etag: 'bar-etag',
              'Last-Modified' => 'bar-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'
      end
    end

    it 'should overwrite existing information if 304 is not received' do
      suppress_internet_availability_check

      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-None-Match' => 'foo-etag',
              'If-Modified-Since' => 'foo-last-modified'
          }
      ).to_return(
          status: 200,
          body: 'bar-cached',
          headers: {
              Etag: 'bar-etag',
              'Last-Modified' => 'bar-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'bar-cached'
        expect_file_content root, 'etag', 'bar-etag'
        expect_file_content root, 'last_modified', 'bar-last-modified'
      end
    end

    it 'should not overwrite existing information if the update request fails' do
      suppress_internet_availability_check

      stub_request(:get, 'http://foo-uri/').with(
          headers: {
              'If-None-Match' => 'foo-etag',
              'If-Modified-Since' => 'foo-last-modified'
          }
      ).to_raise(SocketError)

      Dir.mktmpdir do |root|
        touch root, 'cached', 'foo-cached'
        touch root, 'etag', 'foo-etag'
        touch root, 'last_modified', 'foo-last-modified'

        DownloadCache.new(root).get('http://foo-uri/') { }

        expect_file_content root, 'cached', 'foo-cached'
        expect_file_content root, 'etag', 'foo-etag'
        expect_file_content root, 'last_modified', 'foo-last-modified'

        expect($stderr.string).to match('Unable to update from http://foo-uri/ due to Exception from WebMock. Using cached version.')
      end
    end

    it 'should pass read-only file to block' do
      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        DownloadCache.new(root).get('http://foo-uri/') do |file|
          expect(file.read).to eq('foo-cached')
          -> { file.write('bar') }.should raise_error
        end
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

    it 'should use the buildpack cache if the download cannot be completed' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      Dir.mktmpdir do |root|
        Dir.mktmpdir do |buildpack_cache|
          java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
          FileUtils.mkdir_p java_buildpack_cache
          touch java_buildpack_cache, 'cached', 'foo-stashed'
          with_buildpack_cache(buildpack_cache) do
            DownloadCache.new(root).get('http://foo-uri/') do |file|
              expect(file.read).to eq('foo-stashed')
            end
          end
        end
      end
    end

    it 'should use the buildpack cache if the download cannot be completed because Errno::ENETUNREACH is raised' do
      stub_request(:get, 'http://foo-uri/').to_raise(Errno::ENETUNREACH)

      Dir.mktmpdir do |root|
        Dir.mktmpdir do |buildpack_cache|
          java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
          FileUtils.mkdir_p java_buildpack_cache
          touch java_buildpack_cache, 'cached', 'foo-stashed'
          with_buildpack_cache(buildpack_cache) do
            DownloadCache.new(root).get('http://foo-uri/') do |file|
              expect(file.read).to eq('foo-stashed')
            end
          end
        end
      end
    end

    it 'should use the buildpack cache if the cache configuration disables remote downloads' do
      YAML.stub(:load_file).with(File.expand_path('config/cache.yml')).and_return(
          'remote_downloads' => 'disabled')
      Dir.mktmpdir do |root|
        Dir.mktmpdir do |buildpack_cache|
          java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
          FileUtils.mkdir_p java_buildpack_cache
          touch java_buildpack_cache, 'cached', 'foo-stashed'
          with_buildpack_cache(buildpack_cache) do
            DownloadCache.new(root).get('http://foo-uri/') do |file|
              expect(file.read).to eq('foo-stashed')
            end
          end
        end
      end
    end

    it 'should raise an error if the cache configuration remote downloads setting is invalid' do
      YAML.stub(:load_file).with(File.expand_path('config/cache.yml')).and_return(
          'remote_downloads' => 'junk')
      Dir.mktmpdir do |root|
        Dir.mktmpdir do |buildpack_cache|
          java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
          FileUtils.mkdir_p java_buildpack_cache
          touch java_buildpack_cache, 'cached', 'foo-stashed'
          with_buildpack_cache(buildpack_cache) do
            expect { DownloadCache.new(root).get('http://foo-uri/') }.to raise_error(/Invalid remote_downloads property in cache configuration:/)
          end
        end
      end
    end

    it 'should raise error if download cannot be completed and buildpack cache does not contain the file' do
      stub_request(:get, 'http://foo-uri/').to_raise(SocketError)

      Dir.mktmpdir do |root|
        Dir.mktmpdir do |buildpack_cache|
          java_buildpack_cache = File.join(buildpack_cache, 'java-buildpack')
          FileUtils.mkdir_p java_buildpack_cache
          with_buildpack_cache(buildpack_cache) do
            expect { DownloadCache.new(root).get('http://foo-uri/') { } }.to raise_error
          end
        end
      end
    end

    it 'should fail if a download attempt fails' do
      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      stub_request(:get, 'http://bar-uri/').to_raise(SocketError)

      Dir.mktmpdir do |root|
        DownloadCache.new(root).get('http://foo-uri/') { }
        expect { DownloadCache.new(root).get('http://bar-uri/') { } }.to raise_error(%r(Unable to download from http://bar-uri/))
      end
    end

    def touch(root, extension, content = '')
      file = File.join(root, "http:%2F%2Ffoo-uri%2F.#{extension}")
      File.open(file, 'w') { |f| f.write(content) }
      file
    end

    def expect_file_deleted(extension)
      Dir.mktmpdir do |root|
        file = touch root, extension
        expect(File.exists?(file)).to be_true

        DownloadCache.new(root).evict('http://foo-uri/')

        expect(File.exists?(file)).to be_false
      end
    end

    def expect_file_content(root, extension, content = '')
      file = File.join(root, "http:%2F%2Ffoo-uri%2F.#{extension}")
      expect(File.exists?(file)).to be_true
      File.open(file, 'r') { |f| expect(f.read).to eq(content) }
    end

    def with_buildpack_cache(directory)
      previous_value, ENV['BUILDPACK_CACHE'] = ENV['BUILDPACK_CACHE'], directory
      yield
    ensure
      ENV['BUILDPACK_CACHE'] = previous_value
    end

  end

end
