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

require 'java_buildpack/framework'
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
        download_zip(false)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_javaagent(agent)
        credentials = @application.services.find_service(FILTER, TOKEN)['credentials']
        @droplet.java_opts.add_system_property('sl.token', Shellwords.escape(credentials[TOKEN]))
        @droplet.java_opts.add_system_property('sl.tags', 'pivotal_cloud_foundry')

        # add sl.enableUpgrade system property
        @droplet.java_opts.add_system_property('sl.enableUpgrade', @configuration[ENABLE_UPGRADE] ? 'true' : 'false')

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

      def agent
        @droplet.sandbox + "sl-test-listener-#{@version}.jar"
      end

      # Configuration property names
      TOKEN = 'token'

      ENABLE_UPGRADE = 'enable_upgrade'

      BUILD_SESSION_ID = 'build_session_id'

      LAB_ID = 'lab_id'

      PROXY = 'proxy'

      FILTER = /sealights/.freeze

      private_constant :TOKEN, :ENABLE_UPGRADE, :BUILD_SESSION_ID, :LAB_ID, :PROXY, :FILTER

    end

  end
end
