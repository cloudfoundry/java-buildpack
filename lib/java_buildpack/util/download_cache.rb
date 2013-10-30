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
require 'java_buildpack/diagnostics'
require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/util'
require 'monitor'
require 'net/http'
require 'tmpdir'
require 'uri'
require 'yaml'

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
      @logger = JavaBuildpack::Diagnostics::LoggerFactory.get_logger
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

        internet_up, file_downloaded = DownloadCache.internet_available?(filenames, uri, @logger)

        unless file_downloaded
          if internet_up && should_update(filenames)
            update(filenames, uri)
          elsif should_download(filenames)
            download(filenames, uri, internet_up)
          end
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

    CACHE_CONFIG = '../../../config/cache.yml'.freeze

    HTTP_ERRORS = [
        EOFError,
        Errno::ECONNABORTED,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::EHOSTDOWN,
        Errno::EHOSTUNREACH,
        Errno::EINVAL,
        Errno::ENETDOWN,
        Errno::ENETRESET,
        Errno::ENETUNREACH,
        Errno::ENONET,
        Errno::ENOTCONN,
        Errno::EPIPE,
        Errno::ETIMEDOUT,
        Net::HTTPBadResponse,
        Net::HTTPHeaderSyntaxError,
        Net::ProtocolError,
        SocketError,
        Timeout::Error
    ].freeze

    HTTP_OK = '200'.freeze

    @@monitor = Monitor.new
    @@internet_checked = false
    @@internet_up = true

    def self.get_configuration
      expanded_path = File.expand_path(CACHE_CONFIG, File.dirname(__FILE__))
      YAML.load_file(expanded_path)
    end

    TIMEOUT_SECONDS = 10

    def self.internet_available?(filenames, uri, logger)
      @@monitor.synchronize do
        return @@internet_up, false if @@internet_checked # rubocop:disable RedundantReturn
      end
      cache_configuration = get_configuration
      if cache_configuration['remote_downloads'] == 'disabled'
        return store_internet_availability(false), false # rubocop:disable RedundantReturn
      elsif cache_configuration['remote_downloads'] == 'enabled'
        begin
          rich_uri = URI(uri)

          # Beware known problems with timeouts: https://www.ruby-forum.com/topic/143840
          Net::HTTP.start(rich_uri.host, rich_uri.port, read_timeout: TIMEOUT_SECONDS, connect_timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS) do |http|
            request = Net::HTTP::Get.new(uri)
            http.request request do |response|
              internet_up = response.code == HTTP_OK
              write_response(filenames, response) if internet_up
              return store_internet_availability(internet_up), internet_up # rubocop:disable RedundantReturn
            end
          end
        rescue *HTTP_ERRORS => ex
          logger.debug { "Internet detection failed with #{ex}" }
          return store_internet_availability(false), false # rubocop:disable RedundantReturn
        end
      else
        fail "Invalid remote_downloads property in cache configuration: #{cache_configuration}"
      end
    end

    def self.store_internet_availability(internet_up)
      @@monitor.synchronize do
        @@internet_up = internet_up
        @@internet_checked = true
      end
      internet_up
    end

    def self.clear_internet_availability
      @@monitor.synchronize do
        @@internet_checked = false
      end
    end

    def delete_file(filename)
      File.delete filename if File.exists? filename
    end

    def download(filenames, uri, internet_up)
      if internet_up
        begin
          rich_uri = URI(uri)

          Net::HTTP.start(rich_uri.host, rich_uri.port, use_ssl: DownloadCache.use_ssl?(rich_uri)) do |http|
            request = Net::HTTP::Get.new(uri)
            http.request request do |response|
              DownloadCache.write_response(filenames, response)
            end
          end

        rescue *HTTP_ERRORS => ex
          puts 'FAIL'
          error_message = "Unable to download from #{uri} due to #{ex}"
          raise error_message
        end
      else
        look_aside(filenames, uri)
      end
    end

    def filenames(uri)
      key = URI.escape(uri, '/')
      {
          cached: File.join(@cache_root, "#{key}.cached"),
          etag: File.join(@cache_root, "#{key}.etag"),
          last_modified: File.join(@cache_root, "#{key}.last_modified"),
          lock: File.join(@cache_root, "#{key}.lock")
      }
    end

    # A download has failed, so check the read-only buildpack cache for the file
    # and use the copy there if it exists.
    def look_aside(filenames, uri)
      @logger.debug "Unable to download from #{uri}. Looking in buildpack cache."
      key = URI.escape(uri, '/')
      stashed = File.join(ENV['BUILDPACK_CACHE'], 'java-buildpack', "#{key}.cached")
      @logger.debug { "Looking in buildpack cache for file '#{stashed}'" }
      if File.exist? stashed
        FileUtils.cp(stashed, filenames[:cached])
        @logger.debug "Using copy of #{uri} from buildpack cache."
      else
        message = "Buildpack cache does not contain #{uri}. Failing the download."
        @logger.error message
        @logger.debug { "Buildpack cache contents:\n#{`ls -lR #{File.join(ENV['BUILDPACK_CACHE'], 'java-buildpack')}`}" }
        fail message
      end
    end

    def self.persist_header(response, header, filename)
      unless response[header].nil?
        File.open(filename, File::CREAT | File::WRONLY) do |file|
          file.write(response[header])
          file.fsync
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

      Net::HTTP.start(rich_uri.host, rich_uri.port, use_ssl: DownloadCache.use_ssl?(rich_uri)) do |http|
        request = Net::HTTP::Get.new(uri)
        set_header request, 'If-None-Match', filenames[:etag]
        set_header request, 'If-Modified-Since', filenames[:last_modified]

        http.request request do |response|
          DownloadCache.write_response(filenames, response) unless response.code == '304'
        end
      end

    rescue *HTTP_ERRORS => ex
      @logger.warn "Unable to update from #{uri} due to #{ex}. Using cached version."
    end

    def self.use_ssl?(uri)
      uri.scheme == 'https'
    end

    def self.write_response(filenames, response)
      persist_header response, 'Etag', filenames[:etag]
      persist_header response, 'Last-Modified', filenames[:last_modified]

      File.open(filenames[:cached], File::CREAT | File::WRONLY) do |cached_file|
        response.read_body do |chunk|
          cached_file.write(chunk)
        end
      end
    end

  end

end
