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

require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/util'
require 'monitor'
require 'yaml'

module JavaBuildpack::Util

  # This class maintains the state of internet availability: whether or not it has been checked
  # and whether or not it is deemed to be available.
  #
  # The internet is initially assumed to be available unless +remote_downloads+ is set to +disabled+
  # in +config/cache.yml+.
  class InternetAvailability

    @@monitor = Monitor.new

    @@internet_checked = false

    @@internet_up = true

    # Returns whether or not the internet is deemed to be available.
    #
    # @return [Boolean] +true+ if and only if the internet is deemed to be available
    def self.use_internet?
      @@monitor.synchronize do
        if !@@internet_checked
          remote_downloads_configuration = get_configuration['remote_downloads']
          if remote_downloads_configuration == 'disabled'
            store_internet_availability false
            false
          elsif remote_downloads_configuration == 'enabled'
            true
          else
            fail "Invalid remote_downloads configuration: #{remote_downloads_configuration}"
          end
        else
          @@internet_up
        end
      end
    end

    # Deem the internet to be available.
    def self.internet_available
      store_internet_availability true
    end

    # Deem the internet to be unavailable and log an error if appropriate.
    #
    # @param [String] reason a diagnostic which indicates why the internet should be deemed unavailable
    def self.internet_unavailable(reason)
      if internet_availability_stored?
        JavaBuildpack::Diagnostics::LoggerFactory.get_logger.error(reason)
      end
      store_internet_availability false
    end

    # Returns whether or not the internet availability has been stored.
    #
    # @return [Boolean] +true+ if and only if internet availability has been recorded
    def self.internet_availability_stored?
      @@monitor.synchronize do
        @@internet_checked
      end
    end

    # Clears any record of internet availability.
    def self.clear_internet_availability
      @@monitor.synchronize do
        @@internet_checked = false
      end
    end

    private

    CACHE_CONFIG = '../../../config/cache.yml'.freeze

    def self.get_configuration
      expanded_path = File.expand_path(CACHE_CONFIG, File.dirname(__FILE__))
      YAML.load_file(expanded_path)
    end

    def self.store_internet_availability(internet_up)
      @@monitor.synchronize do
        @@internet_up = internet_up
        @@internet_checked = true
      end
    end

  end
end
