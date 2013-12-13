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
require 'logging_helper'
require 'java_buildpack/util/cache/file_cache'

describe JavaBuildpack::Util::Cache::FileCache do
  include_context 'logging_helper'

  let(:file_cache) { described_class.new(app_dir, 'http://foo-uri/') }

  it 'should create no files on construction' do
    file_cache
    expect_file_absent 'lock'
    expect_empty_cache
  end

  describe 'with populated cache' do

    before do
      populate_cache
    end

    it 'should delete files on destroy' do
      file_cache.destroy
      expect_file_absent 'lock'
      expect_empty_cache
    end

    describe 'immutable cache operations on populated cache' do
      around do |example|
        file_cache.lock_shared do |immutable_cache|
          example.metadata[:immutable_cache] = immutable_cache
          example.run
        end
      end

      it 'should know that data is cached' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        expect(immutable_cache.cached?).to be
      end

      it 'should know that an etag exists' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        expect(immutable_cache.has_etag?).to be
      end

      it 'should know that a last modified timestamp exists' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        expect(immutable_cache.has_last_modified?).to be
      end

      it 'should produce the data' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        immutable_cache.data do |data_file|
          expect(data_file.read).to eq('foo-cached')
        end
      end

      it 'should produce the etag content' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        immutable_cache.any_etag do |etag|
          expect(etag).to eq('foo-etag')
        end
      end

      it 'should produce the last modified timestamp content' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        immutable_cache.any_last_modified do |last_modified|
          expect(last_modified).to eq('foo-last-modified')
        end
      end

      it 'should know the size of the cached data' do |example|
        immutable_cache = example.metadata[:immutable_cache]
        expect(immutable_cache.cached_size).to eq(10)
      end

    end

    describe 'mutable cache operations on populated cache' do
      around do |example|
        file_cache.lock_exclusive do |mutable_cache|
          example.metadata[:mutable_cache] = mutable_cache
          example.run
        end
      end

      it 'should know that data is cached' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        expect(mutable_cache.cached?).to be
      end

      it 'should know that an etag exists' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        expect(mutable_cache.has_etag?).to be
      end

      it 'should know that a last modified timestamp exists' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        expect(mutable_cache.has_last_modified?).to be
      end

      it 'should produce the data' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        mutable_cache.data do |data_file|
          expect(data_file.read).to eq('foo-cached')
        end
      end

      it 'should produce the etag content' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        mutable_cache.any_etag do |etag|
          expect(etag).to eq('foo-etag')
        end
      end

      it 'should produce the last modified timestamp content' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        mutable_cache.any_last_modified do |last_modified|
          expect(last_modified).to eq('foo-last-modified')
        end
      end

      it 'should know the size of the cached data' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        expect(mutable_cache.cached_size).to eq(10)
      end

      it 'should destroy the cache contents' do |example|
        mutable_cache = example.metadata[:mutable_cache]
        mutable_cache.destroy
        expect_empty_cache
      end
    end
  end

  describe 'immutable cache operations on empty cache' do
    around do |example|
      file_cache.lock_shared do |immutable_cache|
        example.metadata[:immutable_cache] = immutable_cache
        example.run
      end
    end

    it 'should know that no data is cached' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      expect(immutable_cache.cached?).not_to be
    end

    it 'should know that no etag exists' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      expect(immutable_cache.has_etag?).not_to be
    end

    it 'should know that no last modified timestamp exists' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      expect(immutable_cache.has_last_modified?).not_to be
    end

    it 'should raise error when asked to produce the data' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      expect { immutable_cache.data }.to raise_error /no data cached/
    end

    it 'should not produce the etag content' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      immutable_cache.any_etag do |etag|
        fail
      end
    end

    it 'should not produce the last modified timestamp content' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      immutable_cache.any_last_modified do |last_modified|
        fail
      end
    end

    it 'should return 0 as the size of the cached data' do |example|
      immutable_cache = example.metadata[:immutable_cache]
      expect(immutable_cache.cached_size).to eq(0)
    end
  end

  describe 'mutable cache operations on empty cache' do
    around do |example|
      file_cache.lock_exclusive do |mutable_cache|
        example.metadata[:mutable_cache] = mutable_cache
        example.run
      end
    end

    it 'should know that no data is cached' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      expect(mutable_cache.cached?).not_to be
    end

    it 'should know that no etag exists' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      expect(mutable_cache.has_etag?).not_to be
    end

    it 'should know that no last modified timestamp exists' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      expect(mutable_cache.has_last_modified?).not_to be
    end

    it 'should raise error when asked to produce the data' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      expect { mutable_cache.data }.to raise_error /no data cached/
    end

    it 'should not produce the etag content' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.any_etag do |etag|
        fail
      end
    end

    it 'should not produce the last modified timestamp content' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.any_last_modified do |last_modified|
        fail
      end
    end

    it 'should return 0 as the size of the cached data' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      expect(mutable_cache.cached_size).to eq(0)
    end

    it 'should persist data' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_data do |cache_file|
        cache_file.write 'new-cached'
      end
      expect_file_content('cached', 'new-cached')
    end

    it 'should persist a file' do |example|
      test_file = app_dir + 'test.file'
      test_file.open('w') { |f| f.write 'new-cached' }
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_file test_file
      expect_file_content('cached', 'new-cached')
    end

    it 'should persist an etag' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_any_etag('new-etag')
      expect_file_content('etag', 'new-etag')
    end

    it 'should not persist a nil etag' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_any_etag(nil)
      expect_empty_cache
    end

    it 'should not persist a nil last modified timestamp' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_any_last_modified(nil)
      expect_empty_cache
    end

    it 'should persist a last modified timestamp' do |example|
      mutable_cache = example.metadata[:mutable_cache]
      mutable_cache.persist_any_last_modified('new-last-modified')
      expect_file_content('last_modified', 'new-last-modified')
    end
  end

  def cache_file(root, extension)
    root + "http:%2F%2Ffoo-uri%2F.#{extension}"
  end

  def expect_complete_cache
    expect_file_content('cached', 'foo-cached')
    expect_file_content('etag', 'foo-etag')
    expect_file_content('last_modified', 'foo-last-modified')
  end

  def expect_file_content(extension, content = '')
    file = cache_file(app_dir, extension)
    expect(file).to exist
    expect(file.read).to eq(content)
  end

  def expect_empty_cache
    expect_file_absent 'cached'
    expect_file_absent 'etag'
    expect_file_absent 'last_modified'
  end

  def expect_file_absent(extension)
    file = cache_file(app_dir, extension)
    expect(file).not_to exist
  end

  def populate_cache
    touch(app_dir, 'lock', 'foo-lock')
    touch(app_dir, 'cached', 'foo-cached')
    touch(app_dir, 'etag', 'foo-etag')
    touch(app_dir, 'last_modified', 'foo-last-modified')
  end

  def touch(root, extension, content = '')
    file = cache_file(root, extension)
    FileUtils.mkdir_p file.dirname
    file.open('w') { |f| f.write(content) }

    file
  end
end
