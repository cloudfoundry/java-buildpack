# Encoding: utf-8
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

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/cache'
require 'java_buildpack/util/cache/file_cache'
require 'uri'

module JavaBuildpack::Util::Cache

  # A read-only stash of files commonly referred to as the "buildpack cache" although it does not have proper caching semantics
  # so it is clearer to refer to it as a "stash".
  class BuildpackStash

    # Creates an instance of the buildpack stash.
    def initialize
      @logger          = JavaBuildpack::Logging::LoggerFactory.get_logger BuildpackStash
      buildpack_cache  = ENV['BUILDPACK_CACHE']
      @buildpack_stash = buildpack_cache ? Pathname.new(buildpack_cache) + 'java-buildpack' : nil
    end

    # A download has failed, so check the read-only buildpack cache for the item
    # and use the copy there if it exists.
    #
    # @param [MutableFileCache] mutable_file_cache a mutable file cache for persisting the item
    # @param [String] uri the uri of the item
    def look_aside(mutable_file_cache, uri)
      fail "Buildpack cache not defined. Cannot look up #{uri}." unless @buildpack_stash

      key     = URI.escape(uri, '/')
      stashed = @buildpack_stash + "#{key}.cached"
      @logger.debug { "Looking in buildpack cache for file '#{stashed}'" }
      if stashed.exist?
        mutable_file_cache.persist_file stashed
        @logger.debug { "Using copy of #{uri} from buildpack cache." }
      else
        message = "Buildpack cache does not contain #{uri}"
        @logger.error { message }
        @logger.debug { "Buildpack cache contents:\n#{`ls -lR #{@buildpack_stash}`}" }
        fail message
      end
    end

  end
end
