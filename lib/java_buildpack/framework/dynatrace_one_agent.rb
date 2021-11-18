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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/cache/internet_availability'
require 'java_buildpack/util/to_b'
require 'json'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Dynatrace SaaS/Managed support.
    class DynatraceOneAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = self.class.to_s.space_case
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @version, @uri = agent_download_url if supports?
        @logger        = JavaBuildpack::Logging::LoggerFactory.instance.get_logger DynatraceOneAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Dynatrace One Agent download location is always accessible'
        ) do
          download(@version, @uri) { |file| expand file }
        end

        @droplet.copy_resources
      rescue StandardError => e
        raise unless skip_errors?

        @logger.error { "Dynatrace OneAgent download failed: #{e}" }
        @logger.warn { "Agent injection disabled because of #{SKIP_ERRORS} credential is set to true!" }
        FileUtils.mkdir_p(error_file.parent)
        File.write(error_file, e.to_s)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        if error_file.exist?
          @logger.warn { "Dynatrace OneAgent injection disabled due to download error: #{File.read(error_file)}" }
          return
        end

        manifest = agent_manifest

        @droplet.java_opts.add_agentpath(agent_path(manifest))
        @droplet.java_opts.add_preformatted_options('-Xshare:off')

        dynatrace_environment_variables(manifest)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, APITOKEN, ENVIRONMENTID
      end

      private

      APIURL = 'apiurl'

      APITOKEN = 'apitoken'

      DT_APPLICATION_ID = 'DT_APPLICATIONID'

      DT_CONNECTION_POINT = 'DT_CONNECTION_POINT'

      DT_TENANT = 'DT_TENANT'

      DT_TENANTTOKEN = 'DT_TENANTTOKEN'

      DT_LOGSTREAM = 'DT_LOGSTREAM'

      DT_NETWORK_ZONE = 'DT_NETWORK_ZONE'

      ENVIRONMENTID = 'environmentid'

      FILTER = /dynatrace/.freeze

      NETWORKZONE = 'networkzone'

      SKIP_ERRORS = 'skiperrors'

      private_constant :APIURL, :APITOKEN, :DT_APPLICATION_ID, :DT_CONNECTION_POINT, :DT_NETWORK_ZONE, :DT_LOGSTREAM,
                       :DT_TENANT, :DT_TENANTTOKEN, :ENVIRONMENTID, :FILTER, :NETWORKZONE, :SKIP_ERRORS

      def agent_download_url
        download_uri = "#{api_base_url(credentials)}/v1/deployment/installer/agent/unix/paas/latest?include=java" \
                       '&bitness=64' \
                       "&Api-Token=#{credentials[APITOKEN]}"

        download_uri += "&networkZone=#{networkzone}" if networkzone?

        ['latest', download_uri]
      end

      def agent_manifest
        JSON.parse(File.read(@droplet.sandbox + 'manifest.json'))
      end

      def agent_path(manifest)
        technologies  = manifest['technologies']
        java_binaries = technologies['java']['linux-x86-64']
        loader        = java_binaries.find { |bin| bin['binarytype'] == 'loader' }
        @droplet.sandbox + loader['path']
      end

      def api_base_url(credentials)
        credentials[APIURL] || "https://#{credentials[ENVIRONMENTID]}.live.dynatrace.com/api"
      end

      def application_id
        @application.details['application_name']
      end

      def application_id?
        @application.environment.key?(DT_APPLICATION_ID)
      end

      def credentials
        @application.services.find_service(FILTER, APITOKEN, ENVIRONMENTID)['credentials']
      end

      def dynatrace_environment_variables(manifest)
        environment_variables = @droplet.environment_variables

        environment_variables
          .add_environment_variable(DT_TENANT, credentials[ENVIRONMENTID])
          .add_environment_variable(DT_TENANTTOKEN, tenanttoken(manifest))
          .add_environment_variable(DT_CONNECTION_POINT, endpoints(manifest))

        environment_variables.add_environment_variable(DT_APPLICATION_ID, application_id) unless application_id?
        environment_variables.add_environment_variable(DT_NETWORK_ZONE, credentials[NETWORKZONE]) if networkzone?
        environment_variables.add_environment_variable(DT_LOGSTREAM, 'stdout') unless logstream?
      end

      def endpoints(manifest)
        "\"#{manifest['communicationEndpoints'].join(';')}\""
      end

      def error_file
        @droplet.sandbox + 'dynatrace_download_error'
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

      def networkzone
        credentials[NETWORKZONE]
      end

      def networkzone?
        credentials.key?(NETWORKZONE)
      end

      def logstream?
        @application.environment.key?(DT_LOGSTREAM)
      end

      def skip_errors?
        credentials[SKIP_ERRORS].to_b
      end

      def tenanttoken(manifest)
        manifest['tenantToken']
      end

      def unpack_agent(root)
        FileUtils.mkdir_p(@droplet.sandbox)
        FileUtils.mv(root + 'agent', @droplet.sandbox)
        FileUtils.mv(root + 'manifest.json', @droplet.sandbox)
      end
    end
  end
end
