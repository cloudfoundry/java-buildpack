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

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch JacCoCo support.
    class SealightsAgent < JavaBuildpack::Component::BaseComponent # JavaBuildpack::Component::VersionedDependencyComponent

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
        @logger.info {"****************** Sealights 'compile'"}
        domain = "staging.sealights.co"
        full_url = "https://#{domain}/api/v2/agents/sealights-java/recommended/download"
        downloadUri(full_url)
        extract_zip("sealights-java.zip", get_agent_path)

      end

      def get_agent_path
        @droplet.sandbox.relative_path_from(@droplet.root)
        # "sealights-java"
      end

      def extract_zip(file, destination)
        @logger.info {"Extracing '#{file}' to '#{destination}'"}
        with_timing "Extracting Sealights Agent to '#{destination}'" do
          FileUtils.mkdir_p(destination)
          shell "unzip -qq #{file} -d #{destination} 2>&1"


          # Zip::File.open(file) do |zip_file|
          #   zip_file.each do |f|
          #     fpath = File.join(destination, f.name)
          #     zip_file.extract(f, fpath) unless File.exist?(fpath)
          #   end
          # end
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @logger.info {"****************** Sealights 'release'"}

        credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
        properties = {
          'sl.token' => credentials[TOKEN],
        }

        properties['sl.buildSessionId'] = credentials['buildSessionId'] if credentials.key? 'buildSessionId'
        properties['sl.buildSessionIdFile'] = credentials['buildSessionIdFile'] if credentials.key? 'buildSessionIdFile'
        properties['sl.proxy'] = credentials['proxy'] if credentials.key? 'proxy'
        properties['port'] = credentials['port'] if credentials.key? 'port'
        properties['output'] = credentials['output'] if credentials.key? 'output'


        agent_path = Pathname.new(get_agent_path + '/sl-test-listener.jar')
        @droplet.java_opts.add_javaagent_with_props(agent_path, properties)
      end

      protected

      def downloadUri(full_url)
        @logger.info { "########## Downloading.... ############" }
        @logger.info { full_url }
        @logger.info { "#######################################" }
        begin
          credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
          token = credentials[TOKEN]
          uri = URI.parse(full_url)
          if credentials.key? 'proxy'
            ENV['http_proxy'] = "http://127.0.0.1:8888"
          end

          response = Net::HTTP.start(uri.host, uri.port,
                                     :use_ssl => uri.scheme == 'https',
                                     :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

            request = Net::HTTP::Get.new uri
            auth = "Bearer #{token}"
            @logger.info { auth }
            request['Authorization'] = auth
            request['accept'] = "application/json"

            http.request request # Net::HTTPResponse object

          end
        end
        case response
        when Net::HTTPSuccess
          @logger.info {"success!"}
          open("sealights-java.zip", "wb") do |file|
            file.write(response.body)
          end
          true
        when Net::HTTPRedirection
          location = response['location']
          @logger.info { "redirected to #{location}" }
          downloadUri(location)
        else
          @logger.error { "Could not retrieve #{full_url}.  Code: #{response.code} Message: #{response.message}" }
          false
        end
      end
      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        puts { "########## !!!!!!!Sealights Supports.... ############" }
        @application.services.one_service? FILTER, TOKEN
      end

      TOKEN = 'token'

      FILTER = /Sealights/.freeze

      private_constant :TOKEN, :FILTER

    end

  end
end
