# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

    # Encapsulates the functionality for enabling zero-touch Ruxit support.
    class RuxitAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri) { |file| expand file }
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

        unless environment.key?(RUXIT_CLUSTER_ID)
          environment_variables.add_environment_variable(RUXIT_CLUSTER_ID, cluster_id)
        end

        environment_variables.add_environment_variable(RUXIT_HOST_ID, host_id) unless environment.key?(RUXIT_HOST_ID)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, TENANT, TENANTTOKEN
      end

      private

      FILTER = /ruxit/.freeze

      RUXIT_APPLICATION_ID = 'RUXIT_APPLICATIONID'.freeze

      RUXIT_CLUSTER_ID = 'RUXIT_CLUSTER_ID'.freeze

      RUXIT_HOST_ID = 'RUXIT_HOST_ID'.freeze

      SERVER = 'server'.freeze

      TENANT = 'tenant'.freeze

      TENANTTOKEN = 'tenanttoken'.freeze

      private_constant :FILTER, :RUXIT_APPLICATION_ID, :RUXIT_CLUSTER_ID, :RUXIT_HOST_ID, :SERVER, :TENANT, :TENANTTOKEN

      def agent_dir
        @droplet.sandbox + 'agent'
      end

      def agent_path
        agent_dir + 'lib64/libruxitagentloader.so'
      end

      def application_id
        @application.details['application_name']
      end

      def cluster_id
        @application.details['application_name']
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

      def host_id
        "#{@application.details['application_name']}_${CF_INSTANCE_INDEX}"
      end

      def server(credentials)
        credentials[SERVER] || "https://#{tenant(credentials)}.live.ruxit.com:443/communication"
      end

      def tenant(credentials)
        credentials[TENANT]
      end

      def tenanttoken(credentials)
        credentials[TENANTTOKEN]
      end

      def unpack_agent(root)
        FileUtils.mkdir_p(@droplet.sandbox)
        FileUtils.mv(root + 'agent', @droplet.sandbox)
      end

    end

  end
end
