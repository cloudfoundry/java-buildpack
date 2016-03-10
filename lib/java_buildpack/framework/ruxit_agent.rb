# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2016 the original author or authors.
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
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Ruxit support.
    class RuxitAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger RuxitAgent
        @logger.debug { "Agent URI to be used: #{@uri.inspect}" }
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri) { |file| expand file }
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        environment = @application.environment
        java_opts   = @droplet.java_opts
        droplet_env = @droplet.environment_variables
        agent_conf = {}
        env = {}

        apply_agent_conf(credentials, agent_conf)
        apply_user_agent_conf(credentials, agent_conf)
        apply_default_environment_variables(env)
        apply_user_environment_variables(environment, env)

        @logger.debug { "agent_conf: #{agent_conf.inspect}" }
        @logger.debug { "ruxit_env: #{env.inspect}" }

        env.each do |key, value|
          droplet_env.add_environment_variable(key, value)
        end
        java_opts.add_agentpath_with_props(agent_path, agent_conf)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, TENANT, TENANT_TOKEN
      end

      private

      FILTER = /ruxit/.freeze
      SERVER = 'server'.freeze
      TENANT = 'tenant'.freeze
      TENANT_TOKEN = 'tenanttoken'.freeze
      RUXIT_APPLICATION_ID = 'RUXIT_APPLICATIONID'.freeze
      RUXIT_CLUSTER_ID = 'RUXIT_CLUSTER_ID'.freeze
      RUXIT_HOST_ID = 'RUXIT_HOST_ID'.freeze

      private_constant :FILTER, :SERVER, :TENANT, :TENANT_TOKEN
      private_constant :RUXIT_CLUSTER_ID, :RUXIT_APPLICATION_ID, :RUXIT_HOST_ID

      def apply_agent_conf(credentials, agent_conf)
        agent_conf[SERVER] = server(credentials)
        agent_conf[TENANT] = tenant(credentials)
        agent_conf[TENANT_TOKEN] = credentials[TENANT_TOKEN]
      end

      def apply_user_agent_conf(credentials, agent_conf)
        credentials.each do |key, value|
          agent_conf[key] = value if [SERVER, TENANT, TENANT_TOKEN].include?(key)
        end
      end

      def apply_default_environment_variables(env)
        env[RUXIT_APPLICATION_ID] = @application.details['application_name']
        env[RUXIT_CLUSTER_ID] = @application.details['application_name']
        env[RUXIT_HOST_ID] = "#{@application.details['application_name']}_${CF_INSTANCE_INDEX}"
      end

      def apply_user_environment_variables(environment, env)
        environment.each do |key, value|
          env[key] = value if key.start_with?('RUXIT_')
        end
      end

      def server(credentials)
        credentials[SERVER] || "https://#{tenant(credentials)}.live.ruxit.com:443/communication"
      end

      def tenant(credentials)
        credentials[TENANT]
      end

      def agent_dir
        @droplet.sandbox + 'agent'
      end

      def agent_path
        agent_dir + lib_name + 'libruxitagentloader.so'
      end

      def architecture
        `uname -m`.strip
      end

      def expand(file)
        with_timing "Expanding Ruxit Agent to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          Dir.mktmpdir do |root|
            root_path = Pathname.new(root)
            shell "unzip -qq #{file.path} -d #{root_path} 2>&1"
            unpack_agent root_path
          end
        end
      end

      def lib_name
        architecture == 'x86_64' || architecture == 'i686' ? 'lib64' : 'lib'
      end

      def unpack_agent(root)
        FileUtils.mkdir_p(agent_dir)
        FileUtils.mv(root + 'agent/bin', agent_dir)
        FileUtils.mv(root + 'agent/conf', agent_dir)
        FileUtils.mv(root + 'agent' + lib_name, agent_dir)
      end
    end
  end
end
