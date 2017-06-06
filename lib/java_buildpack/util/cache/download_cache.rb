# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'java_buildpack/util/cache/cached_file'
require 'java_buildpack/util/cache/inferred_network_failure'
require 'java_buildpack/util/cache/internet_availability'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/sanitizer'
require 'monitor'
require 'net/http'
require 'openssl'
require 'pathname'
require 'tmpdir'
require 'uri'

module JavaBuildpack
  module Util
    module Cache

      # A cache for downloaded files that is configured to use a filesystem as the backing store.
      #
      # Note: this class is thread-safe, however access to the cached files is not
      #
      # References:
      # * {https://en.wikipedia.org/wiki/HTTP_ETag ETag Wikipedia Definition}
      # * {http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html HTTP/1.1 Header Field Definitions}
      class DownloadCache

        # Creates an instance of the cache that is backed by a number of filesystem locations.  The first argument
        # (+mutable_cache_root+) is the only location that downloaded files will be stored in.
        #
        # @param [Pathname] mutable_cache_root the filesystem location in which find cached files in.  This will also be
        #                                      the location that all downloaded files are written to.
        # @param [Pathname] immutable_cache_roots other filesystem locations to find cached files in.  No files will be
        #                                         written to these locations.
        def initialize(mutable_cache_root = Pathname.new(Dir.tmpdir), *immutable_cache_roots)
          @logger                = JavaBuildpack::Logging::LoggerFactory.instance.get_logger DownloadCache
          @mutable_cache_root    = mutable_cache_root
          @immutable_cache_roots = immutable_cache_roots.unshift mutable_cache_root
        end

        # Retrieves an item from the cache. Yields an open file containing the item's content or raises an exception if
        # the item cannot be retrieved.
        #
        # @param [String] uri the URI of the item
        # @yield [file, downloaded] the file representing the cached item and whether the file was downloaded or was
        #                           already in the cache
        # @return [Void]
        def get(uri, &block)
          cached_file             = nil
          downloaded              = nil

          cached_file, downloaded = from_mutable_cache uri if InternetAvailability.instance.available?

          unless cached_file
            cached_file = from_immutable_caches(uri)
            downloaded  = false
          end

          raise "Unable to find cached file for #{uri.sanitize_uri}" unless cached_file
          cached_file.cached(File::RDONLY | File::BINARY, downloaded, &block)
        end

        # Removes an item from the mutable cache.
        #
        # @param [String] uri the URI of the item
        # @return [Void]
        def evict(uri)
          CachedFile.new(@mutable_cache_root, uri, true).destroy
        end

        private

        CA_FILE = (Pathname.new(__FILE__).dirname + '../../../../resources/ca_certs.pem').freeze

        FAILURE_LIMIT = 5

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

        REDIRECT_TYPES = [
          Net::HTTPMovedPermanently,
          Net::HTTPFound,
          Net::HTTPSeeOther,
          Net::HTTPTemporaryRedirect
        ].freeze

        private_constant :CA_FILE, :FAILURE_LIMIT, :HTTP_ERRORS, :REDIRECT_TYPES

        def attempt(http, request, cached_file)
          downloaded = false

          http.request request do |response|
            @logger.debug { "Response headers: #{response.to_hash}" }
            @logger.debug { "Response status: #{response.code}" }

            if response.is_a? Net::HTTPOK
              cache_etag response, cached_file
              cache_last_modified response, cached_file
              cache_content response, cached_file
              downloaded = true
            elsif response.is_a? Net::HTTPNotModified
              @logger.debug { 'Cached copy up to date' }
            elsif redirect?(response)
              downloaded = update URI(response['Location']), cached_file
            else
              raise InferredNetworkFailure, "#{response.code} #{response.message}\n#{response.body}"
            end
          end

          downloaded
        end

        def ca_file(http_options)
          return unless CA_FILE.exist?
          http_options[:ca_file] = CA_FILE.to_s
          @logger.debug { "Adding additional CA certificates from #{CA_FILE}" }
        end

        def cache_content(response, cached_file)
          compressed = compressed?(response)

          cached_file.cached(File::CREAT | File::WRONLY | File::BINARY) do |f|
            @logger.debug { "Persisting content to #{f.path}" }

            f.truncate(0)
            response.read_body { |chunk| f.write chunk }
            f.fsync
          end

          validate_size response['Content-Length'], cached_file unless compressed
        end

        def cache_etag(response, cached_file)
          etag = response['Etag']

          return unless etag

          @logger.debug { "Persisting etag: #{etag}" }

          cached_file.etag(File::CREAT | File::WRONLY | File::BINARY) do |f|
            f.truncate(0)
            f.write etag
            f.fsync
          end
        end

        def cache_last_modified(response, cached_file)
          last_modified = response['Last-Modified']

          return unless last_modified

          @logger.debug { "Persisting last-modified: #{last_modified}" }

          cached_file.last_modified(File::CREAT | File::WRONLY | File::BINARY) do |f|
            f.truncate(0)
            f.write last_modified
            f.fsync
          end
        end

        def client_authentication(http_options)
          client_authentication = JavaBuildpack::Util::ConfigurationUtils.load('cache')['client_authentication']

          certificate_location = client_authentication['certificate_location']
          if certificate_location
            File.open(certificate_location) do |f|
              http_options[:cert] = OpenSSL::X509::Certificate.new f.read
              @logger.debug { "Adding client certificate from #{certificate_location}" }
            end
          end

          private_key_location = client_authentication['private_key_location']

          return unless private_key_location

          File.open(private_key_location) do |f|
            http_options[:key] = OpenSSL::PKey.read f.read, client_authentication['private_key_password']
            @logger.debug { "Adding private key from #{private_key_location}" }
          end
        end

        def compressed?(response)
          %w[br compress deflate gzip x-gzip].include?(response['Content-Encoding'])
        end

        def debug_ssl(http)
          socket = http.instance_variable_get('@socket')
          return unless socket

          io = socket.io
          return unless io

          session = io.session
          @logger.debug { session.to_text } if session
        end

        def from_mutable_cache(uri)
          cached_file = CachedFile.new @mutable_cache_root, uri, true
          cached      = update URI(uri), cached_file
          [cached_file, cached]
        rescue => e
          @logger.warn { "Unable to download #{uri.sanitize_uri} into cache #{@mutable_cache_root}: #{e.message}" }
          nil
        end

        def from_immutable_caches(uri)
          @immutable_cache_roots.each do |cache_root|
            candidate = CachedFile.new cache_root, uri, false

            next unless candidate.cached?

            @logger.debug { "#{uri.sanitize_uri} found in cache #{cache_root}" }
            return candidate
          end

          nil
        end

        # Beware known problems with timeouts: https://www.ruby-forum.com/topic/143840
        def http_options(rich_uri)
          http_options = {}

          if secure?(rich_uri)
            http_options[:use_ssl] = true
            @logger.debug { 'Adding HTTP options for secure connection' }

            ca_file http_options
            client_authentication http_options
          end

          http_options
        end

        def no_proxy?(uri)
          hosts = (ENV['no_proxy'] || ENV['NO_PROXY'] || '').split ','
          hosts.any? { |host| uri.host.end_with? host }
        end

        def proxy(uri)
          proxy_uri = if no_proxy?(uri)
                        URI.parse('')
                      elsif secure?(uri)
                        URI.parse(ENV['https_proxy'] || ENV['HTTPS_PROXY'] || '')
                      else
                        URI.parse(ENV['http_proxy'] || ENV['HTTP_PROXY'] || '')
                      end

          @logger.debug { "Proxy: #{proxy_uri.host}, #{proxy_uri.port}, #{proxy_uri.user}, #{proxy_uri.password}" }
          Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
        end

        def redirect?(response)
          REDIRECT_TYPES.any? { |t| response.is_a? t }
        end

        def request(uri, cached_file)
          request = Net::HTTP::Get.new(uri.request_uri)

          if cached_file.etag?
            cached_file.etag(File::RDONLY | File::BINARY) { |f| request['If-None-Match'] = File.read(f) }
          end

          if cached_file.last_modified?
            cached_file.last_modified(File::RDONLY | File::BINARY) { |f| request['If-Modified-Since'] = File.read(f) }
          end

          @logger.debug { "Request: #{request.path}, #{request.to_hash}" }
          request
        end

        def secure?(uri)
          uri.scheme == 'https'
        end

        def update(uri, cached_file)
          proxy(uri).start(uri.host, uri.port, http_options(uri)) do |http|
            @logger.debug { "HTTP: #{http.address}, #{http.port}, #{http_options(uri)}" }
            debug_ssl(http) if secure?(uri)

            attempt_update(cached_file, http, uri)
          end
        end

        def attempt_update(cached_file, http, uri)
          request = request uri, cached_file
          request.basic_auth uri.user, uri.password if uri.user && uri.password

          failures = 0
          begin
            attempt http, request, cached_file
          rescue InferredNetworkFailure, *HTTP_ERRORS => e
            if (failures += 1) > FAILURE_LIMIT
              InternetAvailability.instance.available false, "Request failed: #{e.message}"
              raise e
            else
              @logger.warn { "Request failure #{failures}, retrying.  Failure: #{e.message}" }
              retry
            end
          end
        end

        def validate_size(expected_size, cached_file)
          return unless expected_size

          actual_size = cached_file.cached(File::RDONLY, &:size)
          @logger.debug { "Validated content size #{actual_size} is #{expected_size}" }

          return if expected_size.to_i == actual_size

          cached_file.destroy
          raise InferredNetworkFailure, "Content has invalid size.  Was #{actual_size}, should be #{expected_size}."
        end

      end

    end
  end
end
