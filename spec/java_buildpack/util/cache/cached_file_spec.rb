# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'digest'
require 'fileutils'
require 'java_buildpack/util/cache/cached_file'

describe JavaBuildpack::Util::Cache::CachedFile do
  include_context 'with application help'

  let(:cache_root) { app_dir + 'cache/root' }

  let(:file_cache) { described_class.new(app_dir, 'http://foo-uri/', true) }

  it 'does not create any files on initialization' do
    %w[cached etag last_modified].each { |extension| expect(cache_file(extension)).not_to exist }
  end

  it 'creates cache_root if mutable' do
    expect(cache_root).not_to exist

    described_class.new(cache_root, 'http://foo-uri/', true)

    expect(cache_root).to exist
  end

  it 'does not create cache_root if immutable' do
    expect(cache_root).not_to exist

    described_class.new(cache_root, 'http://foo-uri/', false)

    expect(cache_root).not_to exist
  end

  it 'does not detect cached file' do
    expect(file_cache).not_to be_cached
  end

  it 'does not detect etag file' do
    expect(file_cache).not_to be_etag
  end

  it 'does not detect last_modified file' do
    expect(file_cache).not_to be_last_modified
  end

  context do

    before do
      touch('cached', 'foo-cached')
      touch('etag', 'foo-etag')
      touch('last_modified', 'foo-last-modified')
    end

    it 'calls the block with the content of the cache file' do
      expect { |b| file_cache.cached(File::RDONLY, 'test-arg', &b) }.to yield_file_with_content(/foo-cached/)
    end

    it 'detects cached file' do
      expect(file_cache).to be_cached
    end

    it 'destroys all files' do
      file_cache.destroy

      %w[cached etag last_modified].each { |extension| expect(cache_file(extension)).not_to exist }
    end

    it 'does not destroy all files if immutable' do
      described_class.new(app_dir, 'http://foo-uri/', false).destroy

      %w[cached etag last_modified].each { |extension| expect(cache_file(extension)).to exist }
    end

    it 'calls the block with the content of the etag file' do
      expect { |b| file_cache.etag(File::RDONLY, 'test-arg', &b) }.to yield_file_with_content(/foo-etag/)
    end

    it 'detects etag file' do
      expect(file_cache).to be_etag
    end

    it 'calls the block with the content of the last_modified file' do
      expect { |b| file_cache.last_modified(File::RDONLY, 'test-arg', &b) }
        .to yield_file_with_content(/foo-last-modified/)
    end

    it 'detects last_modified file' do
      expect(file_cache).to be_last_modified
    end
  end

  def cache_file(extension)
    app_dir + "#{Digest::SHA256.hexdigest('http://foo-uri/')}.#{extension}"
  end

  def touch(extension, content = '')
    file = cache_file extension
    FileUtils.mkdir_p file.dirname
    file.open('w') { |f| f.write content }

    file
  end

end
