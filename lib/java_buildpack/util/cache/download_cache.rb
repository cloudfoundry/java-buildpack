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

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/cache'
require 'java_buildpack/util/cache/buildpack_stash'
require 'java_buildpack/util/cache/file_cache'
require 'java_buildpack/util/cache/internet_availability'
require 'monitor'
require 'net/http'
require 'tmpdir'
require 'uri'

module JavaBuildpack::Util::Cache

  # A cache for downloaded files that is configured to use a filesystem as the backing store. This cache uses standard
  # file locking to ensure that files are not modified concurrently by multiple processes.
  # Reading downloaded files happens concurrently so read performance is not impacted.
  #
  # This class is not thread safe; file locking does not serialise threads in a single process.
  #
  # References:
  # * {https://en.wikipedia.org/wiki/HTTP_ETag ETag Wikipedia Definition}
  # * {http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html HTTP/1.1 Header Field Definitions}
  class DownloadCache # rubocop:disable ClassLength

    # Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
    #
    # @param [String] cache_root the filesystem directory in which to cache downloaded files
    def initialize(cache_root = Pathname.new(Dir.tmpdir))
      @cache_root      = cache_root
      @buildpack_stash = BuildpackStash.new
      @logger          = JavaBuildpack::Logging::LoggerFactory.get_logger DownloadCache
    end

    # Retrieves an item from the cache. Yields an open file containing the item's content or raises an exception if
    # the item cannot be retrieved. In order to ensure that the file is not changed or deleted while it is being used,
    # the cached item is yielded under a shared lock.
    #
    # @param [String] uri the URI of the item
    # @yield [File] the file representing the cached item
    # @return [void]
    def get(uri, &block)
      file_cache = file_cache(uri)

      # The following loop terminates when the item has been yielded to the block or an exception is thrown indicating
      # that the item could not be found in the buildpack cache.
      #
      # The state of the cache is checked under a shared lock. If the cache is in a suitable state, the item is
      # yielded to the block under the shared lock. Otherwise, the shared lock is dropped, an exclusive lock is
      # acquired, the state of the cache is checked again (to avoid duplicating a download by another process) and,
      # if the cache is still not in a suitable state for the item to be yielded, the item is downloaded (or, if the
      # internet is unavailable, copied from the buildpack cache).
      #
      # The loop could fail to terminate if the remote repository was continuously updated, but this should not happen
      # in practice.
      #
      # Network errors are logged and retried. If these errors persist, the internet is deemed to be unavailable and
      # either the currently cached item is yielded to the block or the buildpack cache is consulted.
      loop do
        file_cache.lock_shared do |immutable_file_cache|
          if cache_ready?(immutable_file_cache, uri)
            immutable_file_cache.data(&block)
            return # from get
          end
        end

        file_cache.lock_exclusive do |mutable_file_cache|
          obtain(uri, mutable_file_cache) unless cache_ready?(mutable_file_cache, uri)
        end
      end
    end

    # Removes an item from the cache.
    #
    # @param [String] uri the URI of the item
    # @return [void]
    def evict(uri)
      file_cache(uri).destroy
    end

    private

    INTERNET_DETECTION_RETRY_LIMIT = 5

    DOWNLOAD_RETRY_LIMIT = 5

    TIMEOUT_SECONDS = 10

    HTTP_OK = '200'.freeze

    HTTP_NOT_MODIFIED = '304'.freeze

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

    def add_headers(request, immutable_file_cache)
      immutable_file_cache.any_etag do |etag_content|
        request['If-None-Match'] = etag_content
      end

      immutable_file_cache.any_last_modified do |last_modified_content|
        request['If-Modified-Since'] = last_modified_content
      end
    end

    def download(mutable_file_cache, uri)
      request = Net::HTTP::Get.new(uri)

      issue_http_request(request, uri) do |response, response_code|
        @logger.debug { "Download of #{uri} gave response #{response_code}" }
        if response_code == HTTP_OK
          write_response(mutable_file_cache, response)
        elsif response_code == HTTP_NOT_MODIFIED
          fail(InferredNetworkFailure, "Unexpected HTTP response: #{response_code}")
        end
      end
    rescue => ex
      handle_failure(ex, 1, 1) {}
      false
    end

    def file_cache(uri)
      FileCache.new(@cache_root, uri)
    end

    def handle_failure(exception, try, retry_limit)
      @logger.debug { "HTTP request attempt #{try} of #{retry_limit} failed: #{exception}" }
      if try == retry_limit
        InternetAvailability.internet_unavailable "HTTP request failed: #{exception.message}"
        yield exception, exception.message
      end
    end

    def http_options(rich_uri)
      options = {}
      # Beware known problems with timeouts: https://www.ruby-forum.com/topic/143840
      options = { read_timeout: TIMEOUT_SECONDS, connect_timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS } unless InternetAvailability.internet_availability_stored?
      options.merge(use_ssl: use_ssl?(rich_uri))
    end

    def issue_http_request(request, uri, &block)
      @logger.debug { "HTTP.start(#{start_parameters(uri)})" }
      Net::HTTP.start(*start_parameters(uri)) do |http|
        retry_http_request(http, request, &block)
      end
    end

    # Obtains the file for the given URI by downloading it or, if the internet is deemed to be unavailable, by copying
    # it from the buildpack cache.
    #
    # If downloading fails in any way, marks the internet as unavailable and returns.
    #
    # If the file cannot be found in the buildpack cache, raises an exception.
    def obtain(uri, mutable_file_cache)
      if InternetAvailability.use_internet?
        download(mutable_file_cache, uri)
      else
        @logger.debug { "Unable to download #{uri}. Looking in buildpack cache." }
        @buildpack_stash.look_aside(mutable_file_cache, uri)
      end
    end

    def retry_http_request(http, request, &block)
      1.upto(retry_limit) do |try|
        begin
          http.request request do |response|
            response_code = response.code
            if response_code == HTTP_OK || response_code == HTTP_NOT_MODIFIED
              InternetAvailability.internet_available
              yield response, response_code
              return
            else
              fail(InferredNetworkFailure, "Bad HTTP response: #{response_code}")
            end
          end
        rescue InferredNetworkFailure, *HTTP_ERRORS => ex
          handle_failure(ex, try, retry_limit, &block)
        end
      end
    end

    def retry_limit
      InternetAvailability.internet_availability_stored? ? DOWNLOAD_RETRY_LIMIT : INTERNET_DETECTION_RETRY_LIMIT
    end

    def cache_ready?(immutable_file_cache, uri)
      use_internet      = InternetAvailability.use_internet?
      cached            = immutable_file_cache.cached?
      has_etag          = immutable_file_cache.has_etag?
      has_last_modified = immutable_file_cache.has_last_modified?
      @logger.debug { "should_use_cache for #{uri}, inputs: use_internet? = #{use_internet}, cached? = #{cached}, has_etag? = #{has_etag}, has_last_modified? = #{has_last_modified}" }

      use_cache = false
      if cached && !has_etag && !has_last_modified
        @logger.debug { "Using cache version of #{uri} without up-to-date check since it has no etag or last modified timestamp" }
        use_cache = true
      elsif use_internet && cached && (has_etag || has_last_modified)
        use_cache = up_to_date_check(immutable_file_cache, uri)
      elsif !use_internet && cached
        @logger.debug { "Internet unavailable, so using cached version of #{uri}" }
        use_cache = true
      end

      use_cache
    end

    def start_parameters(uri)
      rich_uri = URI(uri)
      return rich_uri.host, rich_uri.port, http_options(rich_uri) # rubocop:disable RedundantReturn
    end

    def up_to_date_check(immutable_file_cache, uri)
      @logger.debug { "Performing up-to-date check on cached version of #{uri}" }
      use_cache = false

      request = Net::HTTP::Head.new(uri)
      add_headers(request, immutable_file_cache)

      issue_http_request(request, uri) do |_, response_code|
        @logger.debug { "Up-to-date check on cached version of #{uri} returned #{response_code}" }
        if response_code != HTTP_OK
          if response_code != HTTP_NOT_MODIFIED
            @logger.warn { "Unable to check whether or not #{uri} has been modified due to #{response_code}. Using cached version." }
          end

          use_cache = true
        end
      end
      use_cache
    rescue => ex
      handle_failure(ex, 1, 1) {}
      false
    end

    def use_ssl?(rich_uri)
      rich_uri.scheme == 'https'
    end

    def write_response(mutable_file_cache, response)
      mutable_file_cache.persist_any_etag response['Etag']
      mutable_file_cache.persist_any_last_modified response['Last-Modified']

      mutable_file_cache.persist_data do |cached_file|
        response.read_body do |chunk|
          cached_file.write(chunk)
        end
      end

      check_download_file_size(mutable_file_cache, response)
    end

    def check_download_file_size(mutable_file_cache, response)
      expected_size = response['Content-Length']
      if expected_size
        actual_size = mutable_file_cache.cached_size
        if expected_size.to_i != actual_size
          mutable_file_cache.destroy
          fail(InferredNetworkFailure, "Downloaded file has incorrect size (was #{actual_size}, but should be #{expected_size})")
        end
      end
    end

    # Inferred network failure.
    class InferredNetworkFailure < Exception
      def initialize(reason)
        super reason
      end
    end

  end
end
