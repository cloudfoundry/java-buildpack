# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2024 the original author or authors.
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

require 'java_buildpack/framework'
require 'java_buildpack/buildpack_version'
require 'java_buildpack/component/versioned_dependency_component'
require 'shellwords'
require 'fileutils'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Sealights support.
    class SealightsAgent < JavaBuildpack::Component::VersionedDependencyComponent
      # include JavaBuildpack::Util

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger SealightsAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        custom_download_uri = get_value(CUSTOM_AGENT_URL)
        if custom_download_uri.nil?
          download_zip(false)
        else
          target_directory = @droplet.sandbox
          name = @component_name
          download('custom-agent', custom_download_uri, name) do |file|
            expand(file, name, target_directory)
          end
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_javaagent(agent)
        credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
        @droplet.java_opts.add_system_property('sl.token', Shellwords.escape(credentials[TOKEN]))
        @droplet.java_opts.add_system_property('sl.tags', Shellwords.escape("sl-pcf-#{buildpack_version}"))

        # add sl.enableUpgrade system property
        enable_upgrade_value = @configuration[ENABLE_UPGRADE] ? 'true' : 'false'
        custom_download_uri = get_from_cfg_or_svc(credentials, CUSTOM_AGENT_URL)
        unless custom_download_uri.nil? || enable_upgrade_value != 'true'
          @logger.info { 'Switching sl.enableUpgrade to false because agent downloaded from customAgentUrl' }
          enable_upgrade_value = 'false'
        end
        @droplet.java_opts.add_system_property('sl.enableUpgrade', enable_upgrade_value)

        # add sl.proxy system property if defined (either in config or user provisioned service)
        add_system_property_from_cfg_or_svc credentials, 'sl.proxy', PROXY

        # add sl.labId system property if defined (either in config or user provisioned service)
        add_system_property_from_cfg_or_svc credentials, 'sl.labId', LAB_ID

        # add build session if defined in config
        add_system_property 'sl.buildSessionId', BUILD_SESSION_ID
      end

      # wrapper for setting system properties on the droplet from configuration keys
      def add_system_property(system_property, config_key)
        return unless @configuration.key?(config_key)

        @droplet.java_opts.add_system_property(system_property, Shellwords.escape(@configuration[config_key]))
      end

      # add a system property based on either plugin configuration (which takes precedence) or user provisioned service
      def add_system_property_from_cfg_or_svc(svc, system_property, config_key)
        if @configuration.key?(config_key)
          @droplet.java_opts.add_system_property(system_property, Shellwords.escape(@configuration[config_key]))
        elsif svc.key?(config_key)
          @droplet.java_opts.add_system_property(system_property, Shellwords.escape(svc[config_key]))
        end
      end

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, TOKEN
      end

      private

      def buildpack_version
        version_hash = BuildpackVersion.new.to_hash
        if version_hash.key?('version') && version_hash.key?('offline') && version_hash['offline']
          version_hash['version'] + '(offline)'
        elsif version_hash.key?('version')
          version_hash['version']
        else
          'v-unknown'
        end
      end

      def expand(file, name, target_directory)
        with_timing "Expanding #{name} to #{target_directory.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p target_directory
          shell "unzip -qq #{file.path} -d #{target_directory} 2>&1"
        end
      end

      def agent
        custom_download_uri = get_value(CUSTOM_AGENT_URL)
        if custom_download_uri.nil?
          agent_jar_name = "sl-test-listener-#{@version}.jar"
        else
          jars = Dir["#{@droplet.sandbox}/sl-test-listener*.jar"]
          raise 'Failed to find jar which name starts with \'sl-test-listener\' in downloaded zip' if jars.empty?

          agent_jar_name = File.basename(jars[0])
        end
        @droplet.sandbox + agent_jar_name
      end

      def get_from_cfg_or_svc(svc, config_key)
        if @configuration.key?(config_key)
          @configuration[config_key]
        elsif svc.key?(config_key)
          svc[config_key]
        end
      end

      def get_value(config_key)
        svc = @application.services.find_service(FILTER, TOKEN)['credentials']
        get_from_cfg_or_svc(svc, config_key)
      end

      # Configuration property names
      TOKEN = 'token'

      ENABLE_UPGRADE = 'enable_upgrade'

      BUILD_SESSION_ID = 'build_session_id'

      LAB_ID = 'lab_id'

      PROXY = 'proxy'

      CUSTOM_AGENT_URL = 'customAgentUrl'

      FILTER = /sealights/.freeze

      private_constant :TOKEN, :ENABLE_UPGRADE, :BUILD_SESSION_ID, :LAB_ID, :PROXY, :FILTER

    end

  end
end
