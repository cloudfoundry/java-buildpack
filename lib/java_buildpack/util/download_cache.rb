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

require 'java_buildpack/util'
require 'net/http'
require 'tmpdir'
require 'uri'

module JavaBuildpack::Util

  # A cache for downloaded files that is configured to use a filesystem as the backing store. This cache uses standard
  # file locking (<tt>File.flock()</tt>) in order ensure that mutation of files in the cache is non-concurrent across
  # processes.  Reading files (once they've been downloaded) happens concurrently so read performance is not impacted.
  class DownloadCache

    # Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
    #
    # @param [String] cache_root the filesystem root for downloaded files to be cached in
    def initialize(cache_root = Dir.tmpdir)
      Dir.mkdir(cache_root) unless File.exists? cache_root
      @cache_root = cache_root
    end

    # Retrieves an item from the cache.  Retrieval of the item uses the following algorithm:
    #
    # 1. Obtain an exclusive lock based on the URI of the item. This allows concurrency for different items, but not for
    #    the same item.
    # 2. If the the cached item does not exist, download from +uri+ and cache it, its +Etag+, and its +Last-Modified+
    #    values if they exist.
    # 3. If the cached file does exist, and the original download had an +Etag+ or a +Last-Modified+ value, attempt to
    #    download from +uri+ again.  If the result is +304+ (+Not-Modified+), then proceed without changing the cached
    #    item.  If it is anything else, overwrite the cached file and its +Etag+ and +Last-Modified+ values if they exist.
    # 4. Downgrade the lock to a shared lock as no further mutation of the cache is possible.  This allows concurrency for
    #    read access of the item.
    # 5. Yield the cached file (opened read-only) to the passed in block. Once the block is complete, the file is closed
    #    and the lock is released.
    #
    # @param [String] uri the uri to download if the item is not already in the cache.  Also used in the case where the
    #                     item is already in the cache, to validate that the item is up to date
    # @yieldparam [File] file the file representing the cached item. In order to ensure that the file is not changed or
    #                    deleted while it is being used, the cached item can only be accessed as part of a block.
    # @return [void]
    def get(uri)
      filenames = filenames(uri)
      File.open(filenames[:lock], File::CREAT) do |lock_file|
        lock_file.flock(File::LOCK_EX)

        if should_update(filenames)
          update(filenames, uri)
        elsif should_download(filenames)
          download(filenames, uri)
        end

        lock_file.flock(File::LOCK_SH)

        File.open(filenames[:cached], File::RDONLY) do |cached_file|
          yield cached_file
        end
      end
    end

    # Remove an item from the cache
    #
    # @param [String] uri the URI of the item to remove
    # @return [void]
    def evict(uri)
      filenames = filenames(uri)
      File.open(filenames[:lock], File::CREAT) do |lock_file|
        lock_file.flock(File::LOCK_EX)

        delete_file filenames[:cached]
        delete_file filenames[:etag]
        delete_file filenames[:last_modified]
        delete_file filenames[:lock]
      end
    end

    private

    def delete_file(filename)
      File.delete filename if File.exists? filename
    end

    def download(filenames, uri)
      rich_uri = URI(uri)

      Net::HTTP.start(rich_uri.host, rich_uri.port, :use_ssl => (rich_uri.scheme == 'https')) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request request do |response|
          write_response(filenames, response)
        end
      end
    end

    def filenames(uri)
      key = URI.escape(uri, '/')
      {
        :cached => File.join(@cache_root, "#{key}.cached"),
        :etag => File.join(@cache_root, "#{key}.etag"),
        :last_modified => File.join(@cache_root, "#{key}.last_modified"),
        :lock => File.join(@cache_root, "#{key}.lock")
      }
    end

    def persist_header(response, header, filename)
      unless response[header].nil?
        File.open(filename, File::CREAT|File::WRONLY) do |file|
          file.write(response[header])
        end
      end
    end

    def set_header(request, header, filename)
      if File.exists?(filename)
        File.open(filename, File::RDONLY) do |file|
          request[header] = file.read
        end
      end
    end

    def should_download(filenames)
      !File.exists?(filenames[:cached])
    end

    def should_update(filenames)
      File.exists?(filenames[:cached]) && (File.exists?(filenames[:etag]) || File.exists?(filenames[:last_modified]))
    end

    def update(filenames, uri)
      rich_uri = URI(uri)

      Net::HTTP.start(rich_uri.host, rich_uri.port, :use_ssl => (rich_uri.scheme == 'https')) do |http|
        request = Net::HTTP::Get.new(uri)
        set_header request, 'If-None-Match', filenames[:etag]
        set_header request, 'If-Modified-Since', filenames[:last_modified]

        http.request request do |response|
          write_response(filenames, response) unless response.code == '304'
        end
      end
    end

    def write_response(filenames, response)
      persist_header response, 'Etag', filenames[:etag]
      persist_header response, 'Last-Modified', filenames[:last_modified]

      File.open(filenames[:cached], File::CREAT|File::WRONLY) do |cached_file|
        response.read_body do |chunk|
          cached_file.write(chunk)
        end
      end
    end

  end

end
