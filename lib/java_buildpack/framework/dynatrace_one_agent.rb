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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/cache/internet_availability'
require 'json'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Dynatrace SaaS/Managed support.
    class DynatraceOneAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @version, @uri = agent_download_url if supports? && supports_apitoken?
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Dynatrace One Agent download location is always accessible'
        ) do
          download(@version, @uri) { |file| expand file }
        end

        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']

        @droplet.java_opts.add_agentpath_with_props(agent_path,
                                                    SERVER      => server(credentials),
                                                    TENANT      => tenant(credentials),
                                                    TENANTTOKEN => tenanttoken(credentials))

        environment           = @application.environment
        environment_variables = @droplet.environment_variables

        unless environment.key?(RUXIT_APPLICATION_ID)
          environment_variables.add_environment_variable(RUXIT_APPLICATION_ID, application_id)
        end

        environment_variables.add_environment_variable(RUXIT_HOST_ID, host_id) unless environment.key?(RUXIT_HOST_ID)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [ENVIRONMENTID, TENANT], [APITOKEN, TENANTTOKEN]
      end

      def supports_apitoken?
        credentials = @application.services.find_service(FILTER)['credentials']
        credentials[APITOKEN] ? true : false
      end

      private

      FILTER = /ruxit|dynatrace/

      RUXIT_APPLICATION_ID = 'RUXIT_APPLICATIONID'.freeze

      RUXIT_HOST_ID = 'RUXIT_HOST_ID'.freeze

      SERVER = 'server'.freeze

      TENANT = 'tenant'.freeze

      TENANTTOKEN = 'tenanttoken'.freeze

      APITOKEN = 'apitoken'.freeze

      APIURL = 'apiurl'.freeze

      ENVIRONMENTID = 'environmentid'.freeze

      ENDPOINT = 'endpoint'.freeze

      private_constant :FILTER, :RUXIT_APPLICATION_ID, :RUXIT_HOST_ID, :SERVER, :TENANT, :TENANTTOKEN, :APITOKEN
      private_constant :ENVIRONMENTID, :ENDPOINT, :APIURL

      def agent_dir
        @droplet.sandbox + 'agent'
      end

      def agent_path
        libpath = agent_dir + 'lib64/liboneagentloader.so'
        libpath = agent_dir + 'lib64/libruxitagentloader.so' unless File.file?(libpath)
        libpath
      end

      def agent_download_url
        credentials = @application.services.find_service(FILTER)['credentials']
        download_uri = "#{api_base_url}/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&"
        download_uri += "Api-Token=#{credentials[APITOKEN]}"
        ['latest', download_uri]
      end

      def api_base_url
        credentials = @application.services.find_service(FILTER)['credentials']
        return credentials[APIURL] unless credentials[APIURL].nil?
        base_url = credentials[ENDPOINT] || credentials[SERVER] || "https://#{tenant(credentials)}.live.dynatrace.com"
        base_url = base_url.gsub('/communication', '').concat('/api').gsub(':8443', '').gsub(':443', '')
        base_url
      end

      def application_id
        @application.details['application_name']
      end

      def expand(file)
        with_timing "Expanding Dynatrace OneAgent to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          Dir.mktmpdir do |root|
            root_path = Pathname.new(root)
            shell "unzip -qq #{file.path} -d #{root_path} 2>&1"
            unpack_agent root_path
          end
        end
      end

      def host_id
        "#{@application.details['application_name']}_${CF_INSTANCE_INDEX}"
      end

      def server(credentials)
        given_endp = credentials[ENDPOINT] || credentials[SERVER] || "https://#{tenant(credentials)}.live.dynatrace.com"
        supports_apitoken? ? server_from_api : given_endp
      end

      def server_from_api
        endpoints = JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))['communicationEndpoints']
        endpoints.join('\;')
      end

      def tenant(credentials)
        credentials[ENVIRONMENTID] || credentials[TENANT]
      end

      def tenanttoken(credentials)
        supports_apitoken? ? tenanttoken_from_api : credentials[TENANTTOKEN]
      end

      def tenanttoken_from_api
        JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))['tenantToken']
      end

      def unpack_agent(root)
        FileUtils.mkdir_p(@droplet.sandbox)
        FileUtils.mv(root + 'agent', @droplet.sandbox)
        FileUtils.mv(root + 'manifest.json', @droplet.sandbox)
      end

    end

  end
end
