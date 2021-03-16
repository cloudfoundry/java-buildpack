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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'uri'
require 'net/http'
require 'pathname'
require 'base64'
require 'json'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Sealights support.
    class SealightsAgent < JavaBuildpack::Component::BaseComponent

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger SealightsAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? "#{self.class.to_s.dash_case}=latest" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        announce("'compile' method is starting")
        download_url = get_download_url
        download_uri(download_url)
        extract_zip('sealights-java.zip', get_agent_path)
        announce("'compile' method has ended")
      end

      def get_download_url
        credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
        token = credentials[TOKEN]
        sealights_data = token.split(/\./)[1]
        decoded_token = Base64.decode64(sealights_data)
        token_data = JSON.parse(decoded_token)
        "#{token_data['x-sl-server']}/v2/agents/sealights-java/recommended/download"
      end

      def get_agent_path
        @droplet.sandbox
      end

      def extract_zip(file, target_directory)
        with_timing "Extracting Sealights Agent to '#{target_directory}'" do
          FileUtils.mkdir_p(target_directory)
          shell "unzip -qq #{file} -d #{target_directory} 2>&1"
          shell "ls -l #{target_directory} 2>&1"
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
        properties = {
          'sl.token' => credentials[TOKEN]
        }
        properties.map { |k, v| @droplet.java_opts.add_system_property(k, v) }

        @logger.info { "Configuration #{@configuration}" }

        # try_add_system_property(TOKEN)
        try_add_system_property('buildSessionId')
        try_add_system_property('buildSessionIdFile')
        try_add_system_property('proxy')
        try_add_system_property('labId')

        full_path = File.join(get_agent_path, 'sl-test-listener.jar')
        agent_path = Pathname.new(full_path)

        @droplet.java_opts.add_javaagent(agent_path)

        announce("Agent was configured. Agent path is set to: '#{agent_path}")
      end

      def try_add_system_property(key)
        @logger.info { "try_add_system_property #{key}" }
        @logger.info { " @configuration[key] #{@configuration[key]}" }
        @logger.info { " @configuration[key] #{!@configuration[key].nil?}" }
        if !@configuration[key].nil?
          value = @configuration[key]
          prop = 'sl.' + key
          @logger.info { "Adding #{prop}=#{value}" }
          @droplet.java_opts.add_system_property(prop, value)
        else
          @logger.info { "No value for key #{key}" }
        end
      end

      protected

      def download_uri(full_url)
        announce("Downloading Sealights Agent from '#{full_url}'")
        begin
          credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
          token = credentials[TOKEN]
          uri = URI.parse(full_url)
          ENV['http_proxy'] = 'http://127.0.0.1:8888' if credentials.key? 'proxy'

          response = Net::HTTP.start(uri.host, uri.port,
                                     use_ssl: uri.scheme == 'https',
                                     verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
            request = Net::HTTP::Get.new uri
            auth = "Bearer #{token}"
            @logger.info { auth }
            request['Authorization'] = auth
            request['accept'] = 'application/json'

            http.request request # Net::HTTPResponse object
          end
        end
        case response
        when Net::HTTPSuccess
          announce('Agent was downloaded successfully.')
          open('sealights-java.zip', 'wb') do |file|
            file.write(response.body)
          end
          true
        when Net::HTTPRedirection
          location = response['location']
          @logger.info { "redirected to #{location}" }
          downloadUri(location)
        else
          announce('Failed to download the agent.')
          @logger.error { "Could not retrieve #{full_url}.  Code: #{response.code} Message: #{response.message}" }
          false
        end
      end

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, TOKEN
      end
      
      def announce(msg)
        @logger.info { "****************** Sealights Buildpack: #{msg} ******************" }
      end

      TOKEN = 'token'

      FILTER = /Sealights/.freeze

      private_constant :TOKEN, :FILTER

    end

  end
end
