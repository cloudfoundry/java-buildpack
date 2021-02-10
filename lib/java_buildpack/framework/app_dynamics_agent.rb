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

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch AppDynamics support.
    class AppDynamicsAgent < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger AppDynamicsAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip(false, @droplet.sandbox, 'AppDynamics Agent')

        # acessor for resources dir through @droplet?
        resources_dir    = Pathname.new(File.expand_path('../../../resources', __dir__)).freeze
        default_conf_dir = resources_dir + @droplet.component_id + 'defaults'

        copy_appd_default_configuration(default_conf_dir)
        override_default_config_remote
        override_default_config_local
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, 'host-name')['credentials']
        java_opts   = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + 'javaagent.jar')

        application_name java_opts, credentials
        tier_name java_opts, credentials
        node_name java_opts, credentials
        account_access_key java_opts, credentials
        account_name java_opts, credentials
        host_name java_opts, credentials
        port java_opts, credentials
        ssl_enabled java_opts, credentials
        unique_host_name java_opts
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'host-name'
      end

      private

      CONFIG_FILES = %w[logging/log4j2.xml logging/log4j.xml app-agent-config.xml controller-info.xml
                        service-endpoint.xml transactions.xml custom-interceptors.xml
                        custom-activity-correlation.xml].freeze

      FILTER = /app[-]?dynamics/.freeze

      private_constant :CONFIG_FILES, :FILTER

      def application_name(java_opts, credentials)
        name = credentials['application-name'] || @configuration['default_application_name'] ||
          @application.details['application_name']
        java_opts.add_system_property('appdynamics.agent.applicationName', "\\\"#{name}\\\"")
      end

      def account_access_key(java_opts, credentials)
        account_access_key = credentials['account-access-key'] || credentials.dig('account-access-secret', 'secret')
        java_opts.add_system_property 'appdynamics.agent.accountAccessKey', account_access_key if account_access_key
      end

      def account_name(java_opts, credentials)
        account_name = credentials['account-name']
        java_opts.add_system_property 'appdynamics.agent.accountName', account_name if account_name
      end

      def host_name(java_opts, credentials)
        host_name = credentials['host-name']
        raise "'host-name' credential must be set" unless host_name

        java_opts.add_system_property 'appdynamics.controller.hostName', host_name
      end

      def node_name(java_opts, credentials)
        name = credentials['node-name'] || @configuration['default_node_name']
        java_opts.add_system_property('appdynamics.agent.nodeName', name.to_s)
      end

      def port(java_opts, credentials)
        port = credentials['port']
        java_opts.add_system_property 'appdynamics.controller.port', port if port
      end

      def ssl_enabled(java_opts, credentials)
        ssl_enabled = credentials['ssl-enabled']
        java_opts.add_system_property 'appdynamics.controller.ssl.enabled', ssl_enabled if ssl_enabled
      end

      def tier_name(java_opts, credentials)
        name = credentials['tier-name'] || @configuration['default_tier_name'] ||
          @application.details['application_name']
        java_opts.add_system_property('appdynamics.agent.tierName', name.to_s)
      end

      def unique_host_name(java_opts)
        name = @configuration['default_unique_host_name'] || @application.details['application_name']
        java_opts.add_system_property('appdynamics.agent.uniqueHostId', name.to_s)
      end

      # Copy default configuration present in resources folder of app_dynamics_agent ver* directories present in sandbox
      #
      # @param [Pathname] default_conf_dir the 'defaults' directory present in app_dynamics_agent resources.
      # @return [Void]
      def copy_appd_default_configuration(default_conf_dir)
        return unless default_conf_dir.exist?

        Dir.glob(@droplet.sandbox + 'ver*') do |target_directory|
          FileUtils.cp_r "#{default_conf_dir}/.", target_directory
        end
      end

      # Check if configuration file exists on the server before download
      # @param [ResourceURI] uri URI of the remote configuration server
      # @param [ConfigFileName] conf_file Name of the configuration file
      # @return [Boolean] returns true if files exists on path specified by APPD_CONF_HTTP_URL, false otherwise
      def check_if_resource_exists(resource_uri, conf_file)
        # check if resource exists on remote server
        begin
          opts = { use_ssl: true } if resource_uri.scheme == 'https'
          response = Net::HTTP.start(resource_uri.host, resource_uri.port, opts) do |http|
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
          @logger.info { "redirected to #{location}" }
          check_if_resource_exists(location, conf_file)
        else
          @logger.info { "Could not retrieve #{resource_uri}.  Code: #{response.code} Message: #{response.message}" }
          false
        end
      end

      # Check for configuration files on a remote server. If found, copy to conf dir under each ver* dir
      # @return [Void]
      def override_default_config_remote
        return unless @application.environment['APPD_CONF_HTTP_URL']

        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The AppDynamics remote configuration download location is always accessible'
        ) do
          agent_root = @application.environment['APPD_CONF_HTTP_URL'].chomp('/') + '/java/'
          @logger.info { "Downloading override configuration files from #{agent_root}" }
          CONFIG_FILES.each do |conf_file|
            uri = URI(agent_root + conf_file)

            # `download()` uses retries with exponential backoff which is expensive
            # for situations like 404 File not Found. Also, `download()` doesn't expose
            # an api to disable retries, which makes this check necessary to prevent
            # long install times.
            next unless check_if_resource_exists(uri, conf_file)

            download(false, uri.to_s) do |file|
              Dir.glob(@droplet.sandbox + 'ver*') do |target_directory|
                FileUtils.cp_r file, target_directory + '/conf/' + conf_file
              end
            end
          end
        end
      end

      # Check for configuration files locally. If found, copy to conf dir under each ver* dir
      # @return [Void]
      def override_default_config_local
        return unless @application.environment['APPD_CONF_DIR']

        app_conf_dir = @application.root + @application.environment['APPD_CONF_DIR']

        raise "AppDynamics configuration source dir #{app_conf_dir} does not exist" unless Dir.exist?(app_conf_dir)

        @logger.info { "Copy override configuration files from #{app_conf_dir}" }
        CONFIG_FILES.each do |conf_file|
          conf_file_path = app_conf_dir + conf_file

          next unless File.file?(conf_file_path)

          Dir.glob(@droplet.sandbox + 'ver*') do |target_directory|
            FileUtils.cp_r conf_file_path, target_directory + '/conf/' + conf_file
          end
        end
      end
    end
  end
end
