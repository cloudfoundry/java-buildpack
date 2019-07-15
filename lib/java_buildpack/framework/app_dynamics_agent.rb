# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip(false, @droplet.sandbox, 'AppDynamics Agent')

        # acessor for resources dir through @droplet?
        resources_dir = Pathname.new(File.expand_path('../../../resources', __dir__)).freeze
        default_conf_dir = resources_dir + @droplet.component_id + 'defaults'

        copy_appd_default_configuration(default_conf_dir)

        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, 'host-name')['credentials']
        java_opts = @droplet.java_opts
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

      FILTER = /app[-]?dynamics/.freeze

      private_constant :FILTER

      def application_name(java_opts, credentials)
        name = credentials['application-name'] || @configuration['default_application_name'] ||
          @application.details['application_name']
        java_opts.add_system_property('appdynamics.agent.applicationName', name.to_s)
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

    end

  end
end
