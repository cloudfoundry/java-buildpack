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

require 'java_buildpack/util'
require 'java_buildpack/util/sanitizer'
require 'pathname'

module JavaBuildpack
  module Util

    # A module encapsulating all of the utility components for external configuration
    module ExternalConfig

      # Root URL for where external configuration will be located
      def external_config_root
        @application.environment["#{self.class::CONFIG_PREFIX}_CONF_HTTP_URL"].chomp('/') + '/java/'
      end

      # Check for configuration files on a remote server. If found, copy to conf dir under each ver* dir
      # @return [Void]
      def override_default_config_remote
        return unless @application.environment["#{self.class::CONFIG_PREFIX}_CONF_HTTP_URL"]

        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, "The #{self.class.name} remote configuration download location is always accessible"
        ) do
          @logger.info { "Downloading override configuration files from #{external_config_root.sanitize_uri}" }
          self.class::CONFIG_FILES.each do |conf_file|
            uri = URI(external_config_root + conf_file)

            # `download()` uses retries with exponential backoff which is expensive
            # for situations like 404 File not Found. Also, `download()` doesn't expose
            # an api to disable retries, which makes this check necessary to prevent
            # long install times.
            next unless check_if_resource_exists(uri, conf_file)

            download('N/A', uri.to_s) do |file|
              yield file, conf_file
            end
          end
        end
      end

      # Check if configuration file exists on the server before download
      # @param [ResourceURI] resource_uri URI of the remote configuration server
      # @param [ConfigFileName] conf_file Name of the configuration file
      # @return [Boolean] returns true if files exists on path specified by resource_uri, false otherwise
      def check_if_resource_exists(resource_uri, conf_file)
        # check if resource exists on remote server
        begin
          opts = { use_ssl: true } if resource_uri.scheme == 'https'
          response = Net::HTTP.start(resource_uri.host, resource_uri.port, **opts) do |http|
            req = Net::HTTP::Head.new(resource_uri)
            if resource_uri.user != '' || resource_uri.password != ''
              req.basic_auth(resource_uri.user, resource_uri.password)
            end
            http.request(req)
          end
        rescue StandardError => e
          @logger.error { "Request failure: #{e.message}" }
          return false
        end

        case response
        when Net::HTTPSuccess
          true
        when Net::HTTPRedirection
          location = response['location']
          @logger.info { "redirected to #{location.sanitize_uri}" }
          check_if_resource_exists(location, conf_file)
        else
          clean_url = resource_uri.to_s.sanitize_uri
          @logger.info { "Could not fetch #{clean_url}. Code: #{response.code} - #{response.message}" }
          false
        end
      end
    end

  end
end
