# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/util/cache/download_cache'

module JavaBuildpack
  module Util
    module Cache

      # An extension of {DownloadCache} that is configured to use the application cache.  The application
      # cache location is defined by the second argument (<tt>ARGV[1]</tt>) to the +compile+ script.
      #
      # <b>WARNING: This cache should only by used by code run by the +compile+ script</b>
      class ApplicationCache < DownloadCache

        class << self

          # Whether an +ApplicationCache+ can be created
          #
          # @return [Boolean] whether an +ApplicationCache+ can be created
          def available?
            !application_cache_directory.nil?
          end

          # The path to the application cache directory if it exists
          #
          # @return [void, String] the path to the application cache directory if it exists
          def application_cache_directory
            ARGV[1]
          end

        end

        # Creates an instance of the cache that is backed by the the application cache
        def initialize
          logger = Logging::LoggerFactory.instance.get_logger ApplicationCache

          raise 'Application cache directory is undefined' unless self.class.available?
          logger.debug { "Application Cache Directory: #{self.class.application_cache_directory}" }

          super(Pathname.new(self.class.application_cache_directory), CACHED_RESOURCES_DIRECTORY)
        end

      end

    end
  end
end
