# Cloud Foundry Java Buildpack
#
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
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch OverOps (fka Takipi) support.
    class TakipiAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        java_opts = @droplet.java_opts
        java_opts.add_agentpath(@droplet.sandbox + 'lib/libTakipiAgent.so')
        application_name java_opts
        default_env_vars
        credentials = @application.services.find_service(FILTER)['credentials']
        config_env_vars credentials
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [SECRET_KEY, COLLECTOR_HOST]
      end

      private

      FILTER = /takipi/

      SECRET_KEY = 'secret_key'.freeze

      COLLECTOR_HOST = 'collector_host'.freeze

      private_constant :FILTER

      def jvm_lib_file
        @droplet.java_home.root + 'lib/amd64/server/libjvm.so'
      end

      def default_env_vars
        env = @droplet.environment_variables
        sandbox = @droplet.sandbox

        env.add_environment_variable(
          'LD_LIBRARY_PATH',
          "$LD_LIBRARY_PATH:#{qualify_path(sandbox + 'lib', @droplet.root)}"
        )
        env.add_environment_variable('JVM_LIB_FILE', jvm_lib_file)
        env.add_environment_variable('TAKIPI_HOME', sandbox)
        env.add_environment_variable('TAKIPI_MACHINE_NAME', node_name)
      end

      def config_env_vars(credentials)
        env = @droplet.environment_variables

        secret_key = credentials['secret_key']
        env.add_environment_variable 'TAKIPI_SECRET_KEY', secret_key if secret_key

        collector_host = credentials['collector_host']
        env.add_environment_variable 'TAKIPI_MASTER_HOST', collector_host if collector_host

        collector_port = credentials['collector_port']
        env.add_environment_variable 'TAKIPI_MASTER_PORT', collector_port if collector_port
      end

      def application_name(java_opts)
        app_name = @configuration['application_name'] || @application.details['application_name']
        java_opts.add_system_property('takipi.name', app_name)
      end

      def node_name
        "#{@configuration['node_name_prefix']}-$CF_INSTANCE_INDEX"
      end

    end

  end
end
