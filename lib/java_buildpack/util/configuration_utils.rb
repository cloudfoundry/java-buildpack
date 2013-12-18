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

require 'pathname'
require 'java_buildpack/util'
require 'java_buildpack/logging/logger_factory'
require 'yaml'

module JavaBuildpack::Util

  # Utilities for dealing with Groovy applications
  class ConfigurationUtils

    private_class_method :new

    class << self

      # Loads a configuration file from the buildpack configuration directory.  If the configuration file does not exist,
      # returns an empty hash.
      #
      # @param [String] identifier the identifier of the configuration
      # @param [Boolean] should_log whether the contents of the configuration file should be logged.  This value should be
      #                             left to its default and exists to allow the logger to use the utility.
      # @return [Hash] the configuration or an empty hash if the configuration file does not exist
      def load(identifier, should_log = true)
        file = CACHE_DIRECTORY + "#{identifier}.yml"

        if file.exist?
          configuration = YAML.load_file(file)
          logger.debug { "Configuration from #{file}: #{configuration}" } if should_log
        else
          logger.debug { "No configuration file #{file} found" } if should_log
        end

        configuration || {}
      end

      private

      CACHE_DIRECTORY = Pathname.new(File.expand_path('../../../config', File.dirname(__FILE__))).freeze

      def logger
        JavaBuildpack::Logging::LoggerFactory.get_logger ConfigurationUtils
      end

    end

  end

end
