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
require 'fileutils'
require 'java_buildpack/util/cache/cached_file'

describe JavaBuildpack::Util::Cache::CachedFile do
  include_context 'application_helper'

  let(:file_cache) { described_class.new(app_dir, 'http://foo-uri/') }

  it 'should not create any files on initialization' do
    %w(cached etag last_modified).each { |extension| expect(cache_file(extension)).not_to exist }
  end

  it 'should not detect cached file' do
    expect(file_cache.cached?).not_to be
  end

  it 'should not detect etag file' do
    expect(file_cache.etag?).not_to be
  end

  it 'should not detect last_modified file' do
    expect(file_cache.last_modified?).not_to be
  end

  context do

    before do
      touch('cached', 'foo-cached')
      touch('etag', 'foo-etag')
      touch('last_modified', 'foo-last-modified')
    end

    it 'should call the block with the content of the cache file' do
      expect { |b| file_cache.cached(File::RDONLY, 'test-arg', &b) }.to yield_with_args(be_a(File), 'test-arg')
                                                                        .and yield_file_with_content(/foo-cached/)
    end

    it 'should detect cached file' do
      expect(file_cache.cached?).to be
    end

    it 'should destroy all files' do
      file_cache.destroy

      %w(cached etag last_modified).each { |extension| expect(cache_file(extension)).not_to exist }
    end

    it 'should call the block with the content of the etag file' do
      expect { |b| file_cache.etag(File::RDONLY, 'test-arg', &b) }.to yield_with_args(be_a(File), 'test-arg')
                                                                      .and yield_file_with_content(/foo-etag/)
    end

    it 'should detect etag file' do
      expect(file_cache.etag?).to be
    end

    it 'should call the block with the content of the last_modified file' do
      expect { |b| file_cache.last_modified(File::RDONLY, 'test-arg', &b) }.to yield_with_args(be_a(File), 'test-arg')
                                                                               .and yield_file_with_content(/foo-last-modified/)
    end

    it 'should detect last_modified file' do
      expect(file_cache.last_modified?).to be
    end
  end

  def cache_file(extension)
    app_dir + "http:%2F%2Ffoo-uri%2F.#{extension}"
  end

  def touch(extension, content = '')
    file = cache_file extension
    FileUtils.mkdir_p file.dirname
    file.open('w') { |f| f.write content }

    file
  end

end
