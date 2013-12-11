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

require 'java_buildpack/util/cache'
require 'java_buildpack/util/cache/download_cache'

module JavaBuildpack::Util::Cache

  # An extension of {JavaBuildpack::DownloadCache} that is configured to use the global cache.  The global cache location
  # is defined by the +BUILDPACK_CACHE+ environment variable
  class GlobalCache < DownloadCache

    # Creates an instance that is configured to use the global cache.  The global cache location is defined by the
    # +BUILDPACK_CACHE+ environment variable
    #
    # @raise if the +BUILDPACK_CACHE+ environment variable is +nil+
    def initialize
      global_cache_directory = ENV['BUILDPACK_CACHE']
      fail 'Global cache directory is undefined' if global_cache_directory.nil?
      super(Pathname.new(global_cache_directory))
    end

  end

end
