# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'shellwords'
require 'yaml'

module JavaBuildpack
  module Util

    # Utility for loading configuration
    class ConfigurationUtils

      private_class_method :new

      class << self

        # Loads a configuration file from the buildpack configuration directory.  If the configuration file does not
        # exist, returns an empty hash. Overlays configuration in a matching environment variable, on top of the loaded
        # configuration, if present. Will not add a new configuration key where an existing one does not exist.
        #
        # @param [String] identifier the identifier of the configuration
        # @param [Boolean] should_log whether the contents of the configuration file should be logged.  This value
        #                             should be left to its default and exists to allow the logger to use the utility.
        # @return [Hash] the configuration or an empty hash if the configuration file does not exist
        def load(identifier, should_log = true)
          file = CONFIG_DIRECTORY + "#{identifier}.yml"

          if file.exist?
            user_provided = ENV[environment_variable_name(identifier)]
            configuration = load_configuration(file, user_provided, should_log)
          else
            logger.debug { "No configuration file #{file} found" } if should_log
          end

          configuration || {}
        end

        private

        CONFIG_DIRECTORY = Pathname.new(File.expand_path('../../../config', File.dirname(__FILE__))).freeze

        ENVIRONMENT_VARIABLE_PATTERN = 'JBP_CONFIG_'

        private_constant :CONFIG_DIRECTORY, :ENVIRONMENT_VARIABLE_PATTERN

        def load_configuration(file, user_provided, should_log)
          configuration = YAML.load_file(file)
          logger.debug { "Configuration from #{file}: #{configuration}" } if should_log

          if user_provided
            user_provided_value = YAML.load(user_provided)
            if user_provided_value.is_a?(Hash)
              configuration = do_merge(configuration, user_provided_value, should_log)
            elsif user_provided_value.is_a?(Array)
              user_provided_value.each do |new_prop|
                configuration = do_merge(configuration, new_prop, should_log)
              end
            else
              fail "User configuration value is not valid: #{user_provided_value}"
            end
            logger.debug { "Configuration from #{file} modified with: #{user_provided}" } if should_log
          end

          configuration
        end

        def do_merge(hash_v1, hash_v2, should_log)
          hash_v2.each do |key, value|
            if hash_v1.key? key
              hash_v1[key] = do_resolve_value(key, hash_v1[key], value, should_log)
            else
              logger.warn { "User config value for '#{key}' is not valid, existing property not present" } if should_log
            end
          end
          hash_v1
        end

        def do_resolve_value(key, v1, v2, should_log)
          return do_merge(v1, v2, should_log) if v1.is_a?(Hash) && v2.is_a?(Hash)
          return v2 if (!v1.is_a?(Hash)) && (!v2.is_a?(Hash))
          logger.warn { "User config value for '#{key}' is not valid, must be of a similar type" } if should_log
          v1
        end

        def environment_variable_name(config_name)
          ENVIRONMENT_VARIABLE_PATTERN + config_name.upcase
        end

        def logger
          JavaBuildpack::Logging::LoggerFactory.instance.get_logger ConfigurationUtils
        end

      end

    end

  end
end
