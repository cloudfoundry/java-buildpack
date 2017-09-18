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
        @version, @uri = agent_download_url if supports?
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
        credentials = service['credentials']

        @droplet.java_opts.add_agentpath(agent_path)

        environment           = @application.environment
        environment_variables = @droplet.environment_variables

        unless environment.key?(DT_APPLICATION_ID)
          environment_variables.add_environment_variable(DT_APPLICATION_ID, application_id)
        end

        environment_variables.add_environment_variable(DT_HOST_ID, host_id) unless environment.key?(DT_HOST_ID)
        environment_variables.add_environment_variable(DT_TENANT, credentials[ENVIRONMENTID])
        environment_variables.add_environment_variable(DT_TENANTTOKEN, tenanttoken)
        environment_variables.add_environment_variable(DT_CONNECTION_POINT, endpoints)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        !service.nil?
      end

      private

      FILTER = /dynatrace/

      DT_APPLICATION_ID = 'DT_APPLICATIONID'.freeze

      DT_HOST_ID = 'DT_HOST_ID'.freeze

      DT_TENANT = 'DT_TENANT'.freeze

      DT_TENANTTOKEN = 'DT_TENANTTOKEN'.freeze

      DT_CONNECTION_POINT = 'DT_CONNECTION_POINT'.freeze

      APITOKEN = 'apitoken'.freeze

      APIURL = 'apiurl'.freeze

      ENVIRONMENTID = 'environmentid'.freeze

      private_constant :FILTER, :DT_APPLICATION_ID, :DT_HOST_ID
      private_constant :DT_TENANT, :DT_TENANTTOKEN, :DT_CONNECTION_POINT
      private_constant :ENVIRONMENTID, :APITOKEN

      def service
        candidates = @application.services.select do |candidate|
          (
            candidate['name'] =~ FILTER ||
            candidate['label'] =~ FILTER ||
            candidate['tags'].any? { |tag| tag =~ FILTER }
          ) &&
          candidate['credentials'][ENVIRONMENTID] && candidate['credentials'][APITOKEN]
        end

        candidates.one? ? candidates.first : nil
      end

      def agent_path
        technologies = JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))['technologies']
        java_binaries = technologies['java']['linux-x86-64']
        loader = java_binaries.find { |bin| bin['binarytype'] == 'loader' }
        @droplet.sandbox + loader['path']
      end

      def agent_download_url
        credentials = service['credentials']
        download_uri = "#{api_base_url}/v1/deployment/installer/agent/unix/paas/latest?include=java&bitness=64&"
        download_uri += "Api-Token=#{credentials[APITOKEN]}"
        ['latest', download_uri]
      end

      def api_base_url
        credentials = service['credentials']
        credentials[APIURL] || "https://#{credentials[ENVIRONMENTID]}.live.dynatrace.com/api"
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

      def tenanttoken
        JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))['tenantToken']
      end

      def endpoints
        '"' + JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))['communicationEndpoints'].join(';') + '"'
      end

      def unpack_agent(root)
        FileUtils.mkdir_p(@droplet.sandbox)
        FileUtils.mv(root + 'agent', @droplet.sandbox)
        FileUtils.mv(root + 'manifest.json', @droplet.sandbox)
      end

    end

  end
end
