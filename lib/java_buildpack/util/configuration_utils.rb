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
        # @param [String] identifier the identifier of the configuration to load
        # @param [Boolean] clean_nil_values whether empty/nil values should be removed along with their keys from the
        #                                  returned configuration.
        # @param [Boolean] should_log whether the contents of the configuration file should be logged.  This value
        #                             should be left to its default and exists to allow the logger to use the utility.
        # @return [Hash] the configuration or an empty hash if the configuration file does not exist
        def load(identifier, clean_nil_values = true, should_log = true)
          file = file_name(identifier)

          if file.exist?
            var_name      = environment_variable_name(identifier)
            user_provided = ENV[var_name]
            configuration = load_configuration(file, user_provided, var_name, clean_nil_values, should_log)
          elsif should_log
            logger.debug { "No configuration file #{file} found" }
          end

          configuration || {}
        end

        # Write a new configuration file to the buildpack configuration directory. Any existing file will be replaced.
        #
        # @param [String] identifier the identifier of the configuration to write
        # @param [Boolean] should_log whether the contents of the configuration file should be logged.  This value
        #                             should be left to its default and exists to allow the logger to use the utility.
        def write(identifier, new_content, should_log = true)
          file = file_name(identifier)

          if file.exist?
            logger.debug { "Writing configuration file #{file}" } if should_log
            header = header(file)

            File.open(file, 'w') do |f|
              header.each { |line| f.write line }
              YAML.dump(new_content, f)
            end
          elsif should_log
            logger.debug { "No configuration file #{file} found" }
          end
        end

        private

        CONFIG_DIRECTORY = Pathname.new(File.expand_path('../../../config', File.dirname(__FILE__))).freeze

        ENVIRONMENT_VARIABLE_PATTERN = 'JBP_CONFIG_'

        private_constant :CONFIG_DIRECTORY, :ENVIRONMENT_VARIABLE_PATTERN

        def clean_nil_values(configuration)
          configuration.each do |key, value|
            if value.is_a?(Hash)
              configuration[key] = clean_nil_values value
            elsif value.nil?
              configuration.delete key
            end
          end
          configuration
        end

        def file_name(identifier)
          CONFIG_DIRECTORY + "#{identifier}.yml"
        end

        def header(file)
          header = []
          File.open(file, 'r') do |f|
            f.each do |line|
              break if line =~ /^---/
              raise unless line =~ /^#/ || line =~ /^$/
              header << line
            end
          end
          header
        end

        def load_configuration(file, user_provided, var_name, clean_nil_values, should_log)
          configuration = YAML.load_file(file)
          logger.debug { "Configuration from #{file}: #{configuration}" } if should_log

          if user_provided
            begin
              user_provided_value = YAML.safe_load(user_provided)
              configuration       = merge_configuration(configuration, user_provided_value, var_name, should_log)
            rescue Psych::SyntaxError => ex
              raise "User configuration value in environment variable #{var_name} has invalid syntax: #{ex}"
            end
            logger.debug { "Configuration from #{file} modified with: #{user_provided}" } if should_log
          end

          clean_nil_values configuration if clean_nil_values
          configuration
        end

        def merge_configuration(configuration, user_provided_value, var_name, should_log)
          if user_provided_value.is_a?(Hash)
            configuration = do_merge(configuration, user_provided_value, should_log)
          elsif user_provided_value.is_a?(Array)
            user_provided_value.each { |new_prop| configuration = do_merge(configuration, new_prop, should_log) }
          else
            raise "User configuration value in environment variable #{var_name} is not valid: #{user_provided_value}"
          end
          configuration
        end

        def do_merge(hash_v1, hash_v2, should_log)
          hash_v2.each do |key, value|
            if hash_v1.key? key
              hash_v1[key] = do_resolve_value(key, hash_v1[key], value, should_log)
            elsif should_log
              logger.warn { "User config value for '#{key}' is not valid, existing property not present" }
            end
          end
          hash_v1
        end

        def do_resolve_value(key, v1, v2, should_log)
          return do_merge(v1, v2, should_log) if v1.is_a?(Hash) && v2.is_a?(Hash)
          return v2 if !v1.is_a?(Hash) && !v2.is_a?(Hash)
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
