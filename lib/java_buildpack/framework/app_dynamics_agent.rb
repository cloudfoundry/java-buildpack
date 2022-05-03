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
require 'shellwords'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/external_config'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch AppDynamics support.
    class AppDynamicsAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util::ExternalConfig

      # Full list of configuration files that can be downloaded remotely
      CONFIG_FILES = %w[logging/log4j2.xml logging/log4j.xml app-agent-config.xml controller-info.xml
                        service-endpoint.xml transactions.xml custom-interceptors.xml
                        custom-activity-correlation.xml].freeze

      # Prefix to be used with external configuration environment variable
      CONFIG_PREFIX = 'APPD'

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
        override_default_config_remote(&method(:save_cfg_file))
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

      FILTER = /app-?dynamics/.freeze

      private_constant :FILTER

      def application_name(java_opts, credentials)
        name = escape(@application.details['application_name'])
        name = @configuration['default_application_name'] if @configuration['default_application_name']
        name = escape(credentials['application-name']) if credentials['application-name']

        java_opts.add_system_property('appdynamics.agent.applicationName', name.to_s)
      end

      def account_access_key(java_opts, credentials)
        account_access_key = credentials['account-access-key'] || credentials.dig('account-access-secret', 'secret')
        account_access_key = escape(account_access_key)

        java_opts.add_system_property 'appdynamics.agent.accountAccessKey', account_access_key if account_access_key
      end

      def account_name(java_opts, credentials)
        account_name = credentials['account-name']
        java_opts.add_system_property 'appdynamics.agent.accountName', escape(account_name) if account_name
      end

      def host_name(java_opts, credentials)
        host_name = credentials['host-name']
        raise "'host-name' credential must be set" unless host_name

        java_opts.add_system_property 'appdynamics.controller.hostName', escape(host_name)
      end

      def node_name(java_opts, credentials)
        name = @configuration['default_node_name']
        name = escape(credentials['node-name']) if credentials['node-name']

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
        name = escape(@application.details['application_name'])
        name = @configuration['default_tier_name'] if @configuration['default_tier_name']
        name = escape(credentials['tier-name']) if credentials['tier-name']

        java_opts.add_system_property('appdynamics.agent.tierName', name.to_s)
      end

      def unique_host_name(java_opts)
        name = escape(@application.details['application_name'])
        name = @configuration['default_unique_host_name'] if @configuration['default_unique_host_name']

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

          save_cfg_file(conf_file_path, conf_file)
        end
      end

      def save_cfg_file(file, conf_file)
        Dir.glob(@droplet.sandbox + 'ver*') do |target_directory|
          FileUtils.cp_r file, target_directory + '/conf/' + conf_file
        end
      end

      def escape(value)
        if /\$[({][^)}]+[)}]/ =~ value
          "\\\"#{value}\\\""
        else
          Shellwords.escape(value)
        end
      end
    end
  end
end
