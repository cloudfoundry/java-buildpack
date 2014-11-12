# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
        download_zip false
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts

        java_opts
        .add_javaagent(@droplet.sandbox + 'javaagent.jar')
        .add_system_property('appdynamics.agent.nodeName',
                             "#{@application.details['application_name']}-$(expr \"$VCAP_APPLICATION\" : '.*instance_index[\": ]*\\([[:digit:]]*\\).*')")

        application_name(java_opts)
        tier_name(java_opts, credentials)
        account_access_key(java_opts, credentials)
        account_name(java_opts, credentials)
        host_name(java_opts, credentials)
        port(java_opts, credentials)
        ssl_enabled(java_opts, credentials)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'host-name'
      end

      private

      FILTER = /app-dynamics/.freeze

      private_constant :FILTER

      def application_name(java_opts)
        app_name =  @application.environment['APPDYNAMICS_ENV_NAME'] ?  @application.environment['APPDYNAMICS_ENV_NAME'] : @application.details['application_name']
        java_opts.add_system_property 'appdynamics.agent.applicationName', app_name
      end

      def tier_name(java_opts, credentials)
        default_tier_name = credentials.key?('tier-name') ? credentials['tier-name'] : @configuration['default_tier_name']
        tier_name =  @application.environment['APPDYNAMICS_APP_NAME'] ?  @application.environment['APPDYNAMICS_APP_NAME'] : default_tier_name
        java_opts.add_system_property 'appdynamics.agent.tierName', tier_name
      end

      def account_access_key(java_opts, credentials)
        account_access_key = credentials['account-access-key']
        java_opts.add_system_property 'appdynamics.agent.accountAccessKey', account_access_key if account_access_key
      end

      def account_name(java_opts, credentials)
        account_name = credentials['account-name']
        java_opts.add_system_property 'appdynamics.agent.accountName', account_name if account_name
      end

      def host_name(java_opts, credentials)
        host_name = credentials['host-name']
        fail "'host-name' credential must be set" unless host_name
        java_opts.add_system_property 'appdynamics.controller.hostName', host_name
      end

      def port(java_opts, credentials)
        port = credentials['port']
        java_opts.add_system_property 'appdynamics.controller.port', port if port
      end

      def ssl_enabled(java_opts, credentials)
        ssl_enabled = credentials['ssl-enabled']
        java_opts.add_system_property 'appdynamics.controller.ssl.enabled', ssl_enabled if ssl_enabled
      end

    end

  end
end
