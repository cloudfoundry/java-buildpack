# frozen_string_literal: true

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
require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'fileutils'
require 'net/http'
require 'json'
require 'date'
require 'cgi'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Seeker support.
    class SeekerSecurityProvider < JavaBuildpack::Component::BaseComponent
      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger SeekerSecurityProvider
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @application.services.one_service? FILTER
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)

      def compile
        @logger.info { 'Seeker buildpack compile stage start' }
        credentials = fetch_credentials
        @logger.info { "Credentials #{credentials}" }
        assert_configuration_valid(credentials)
        if should_download_sensor(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY])
          fetch_agent_within_sensor(credentials)
        else
          fetch_agent_direct(credentials)
        end
        @droplet.copy_resources
      end

      # extract seeker relevant configuration as map
      def fetch_credentials
        service = @application.services.find_service FILTER
        service['credentials']
      end

      # verify required agent configuration is present
      def assert_configuration_valid(credentials)
        mandatory_config_keys =
          [ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY, SENSOR_HOST_SERVICE_CONFIG_KEY,
           SENSOR_PORT_SERVICE_CONFIG_KEY, SEEKER_SERVER_URL_CONFIG_KEY]
        mandatory_config_keys.each do |config_key|
          raise "'#{config_key}' credential must be set" unless credentials[config_key]
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @logger.info { 'Seeker buildpack release stage start' }
        credentials = fetch_credentials
        @droplet.java_opts.add_javaagent(@droplet.sandbox + 'seeker-agent.jar')
        @droplet.environment_variables
                .add_environment_variable('SEEKER_SENSOR_HOST', credentials[SENSOR_HOST_SERVICE_CONFIG_KEY])
                .add_environment_variable('SEEKER_SENSOR_HTTP_PORT', credentials[SENSOR_PORT_SERVICE_CONFIG_KEY])
                .add_environment_variable('SEEKER_SERVER_URL', credentials[SEEKER_SERVER_URL_CONFIG_KEY])
      end

      # JSON key for the host of the seeker sensor
      SENSOR_HOST_SERVICE_CONFIG_KEY = 'sensor_host'

      # JSON key for the port of the seeker sensor
      SENSOR_PORT_SERVICE_CONFIG_KEY = 'sensor_port'
      # JSON key for the address of seeker sensor
      SEEKER_SERVER_URL_CONFIG_KEY = 'seeker_server_url'

      # Enterprise server url, for example: `https://seeker-server.com:8082`
      ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY = 'enterprise_server_url'

      # Relative path of the sensor zip
      SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER = 'rest/ui/installers/binaries/LINUX'

      # Relative path of the Java agent jars after Sensor extraction
      AGENT_JARS_PATH = 'inline/agents/java/*'

      # Relative path of the agent zip
      AGENT_PATH = '/rest/api/latest/installers/agents/binaries/JAVA'

      # Version details of Seekers server REST API path
      SEEKER_VERSION_API = '/rest/api/version'

      # seeker service name identifier
      FILTER = /seeker/.freeze

      private_constant :SENSOR_HOST_SERVICE_CONFIG_KEY, :SENSOR_PORT_SERVICE_CONFIG_KEY,
                       :ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY, :SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER,
                       :AGENT_JARS_PATH, :AGENT_PATH, :SEEKER_VERSION_API

      private

      def should_download_sensor(server_base_url)
        json_response = get_seeker_version_details(server_base_url)
        @logger.debug { "Seeker server response for version WS: #{json_response}" }
        seeker_version_response = JSON.parse(json_response)
        seeker_version = seeker_version_response['version']
        version_prefix = seeker_version[0, 7]
        last_seeker_version_without_agent_direct_download_date = Date.parse('2018.05.01')
        @logger.info { "Current Seeker version #{version_prefix}" }
        current_seeker_version = Date.parse(version_prefix + '.01')
        current_seeker_version <= last_seeker_version_without_agent_direct_download_date
      end

      def get_seeker_version_details(server_base_url)
        uri = URI.parse(server_base_url)
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.use_ssl = true
        end
        http_response = http.request_get(SEEKER_VERSION_API)
        http_response.body
      end

      def agent_direct_link(credentials)
        URI.join(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY], AGENT_PATH).to_s
      end

      def fetch_agent_direct(credentials)
        @logger.info { 'Trying to download agent directly...' }
        java_agent_zip_uri = agent_direct_link(credentials)
        download_agent(java_agent_zip_uri)
      end

      def download_agent(java_agent_zip_uri)
        @logger.debug { "Before downloading Agent from: #{java_agent_zip_uri}" }
        download_zip('', java_agent_zip_uri, false, @droplet.sandbox)
      end

      def fetch_agent_within_sensor(credentials)
        @logger.info { 'Trying to download sensor...' }
        seeker_tmp_dir = @droplet.sandbox + 'seeker_tmp_sensor'
        shell "rm -rf #{seeker_tmp_dir}"
        sensor_direct_link = sensor_direct_link(credentials)
        @logger.debug { "Before downloading Sensor from: #{sensor_direct_link}" }
        download_zip('', sensor_direct_link,
                     false, seeker_tmp_dir, 'SensorInstaller.zip')
        inner_jar_file = seeker_tmp_dir + 'SeekerInstaller.jar'
        # Unzip only the java agent - to save time
        shell "unzip -j #{inner_jar_file} #{AGENT_JARS_PATH} -d #{@droplet.sandbox} 2>&1"
        shell "rm -rf #{seeker_tmp_dir}"
      end

      def sensor_direct_link(credentials)
        enterprise_server_uri = URI.parse(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY].strip)
        URI.join(enterprise_server_uri, SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER).to_s
      end
    end
  end
end
