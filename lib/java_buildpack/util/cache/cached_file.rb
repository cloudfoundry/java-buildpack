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

require 'digest'
require 'fileutils'
require 'java_buildpack/util/cache'
require 'java_buildpack/util/sanitizer'

module JavaBuildpack
  module Util
    module Cache

      # Represents a file cached on a filesystem
      #
      # Note: this class is thread-safe, however access to the cached files is not
      class CachedFile
        include JavaBuildpack::Util

        # Creates an instance of the cached file.  Files created and expected by this class will all be rooted at
        # +cache_root+.
        #
        # @param [Pathname] cache_root the filesystem root for the file created and expected by this class
        # @param [String] uri a uri which uniquely identifies the file in the cache
        # @param [Boolean] mutable whether the cached file should be mutable
        def initialize(cache_root, uri, mutable)
          key            = Digest::SHA256.hexdigest uri.sanitize_uri
          @cached        = cache_root + "#{key}.cached"
          @etag          = cache_root + "#{key}.etag"
          @last_modified = cache_root + "#{key}.last_modified"
          @mutable       = mutable

          FileUtils.mkdir_p cache_root if mutable
        end

        # Opens the cached file
        #
        # @param [String, integer] mode_enc the mode to open the file in.  Can be a string like +"r"+ or an integer like
        #                                   +File::CREAT | File::WRONLY+.
        # @param [Array] additional_args any additional arguments to be passed to the block
        # @yield [file, additional_args] the cached file and any additional arguments passed in
        # @return [Void]
        def cached(mode_enc, *additional_args, &_)
          @cached.open(mode_enc) { |f| yield f, *additional_args }
        end

        # Returns whether or not data is cached.
        #
        # @return [Boolean] +true+ if and only if data is cached
        def cached?
          @cached.exist?
        end

        # Destroys the cached file
        def destroy
          [@cached, @etag, @last_modified].each { |f| f.delete if f.exist? } if @mutable
        end

        # Opens the etag file
        #
        # @param [String, integer] mode_enc the mode to open the file in.  Can be a string like +"r"+ or an integer like
        #                                   +File::CREAT | File::WRONLY+.
        # @param [Array] additional_args any additional arguments to be passed to the block
        # @yield [file] the etag file
        # @return [Void]
        def etag(mode_enc, *additional_args, &_)
          @etag.open(mode_enc) { |f| yield f, *additional_args }
        end

        # Returns whether or not an etag is stored.
        #
        # @return [Boolean] +true+ if and only if an etag is stored
        def etag?
          @etag.exist?
        end

        # Opens the last modified file
        #
        # @param [String, integer] mode_enc the mode to open the file in.  Can be a string like +"r"+ or an integer like
        #                                   +File::CREAT | File::WRONLY+.
        # @param [Array] additional_args any additional arguments to be passed to the block
        # @yield [file] the last modified file
        # @return [Void]
        def last_modified(mode_enc, *additional_args, &_)
          @last_modified.open(mode_enc) { |f| yield f, *additional_args }
        end

        # Returns whether or not a last modified time stamp is stored.
        #
        # @return [Boolean] +true+ if and only if a last modified time stamp is stored
        def last_modified?
          @last_modified.exist?
        end

      end

    end
  end
end
