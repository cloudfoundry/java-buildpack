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
require 'java_buildpack/framework'
require 'java_buildpack/util/service_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Framework

  # Encapsulates the functionality for enabling zero-touch AppDynamics support.
  class AppDynamics < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('AppDynamics Agent', context)
    end

    def compile
      FileUtils.rm_rf app_dynamics_home
      FileUtils.mkdir_p app_dynamics_home
      download_zip app_dynamics_home, false
    end

    def release
      credentials = JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)['credentials']

      @java_opts << "-javaagent:#{@application.relative_path_to(app_dynamics_home) + 'javaagent.jar'}"
      @java_opts << host_name(credentials)
      @java_opts << port(credentials)
      @java_opts << ssl_enabled(credentials)
      @java_opts << "-Dappdynamics.agent.applicationName='#{@vcap_application[KEY_NAME]}'"
      @java_opts << "-Dappdynamics.agent.tierName='#{@configuration['tier_name']}'"
      @java_opts << "-Dappdynamics.agent.nodeName=$(expr \"$VCAP_APPLICATION\" : '.*instance_id[\": ]*\"\\([a-z0-9]\\+\\)\".*')"
      @java_opts << account_name(credentials)
      @java_opts << account_access_key(credentials)
    end

    protected

    def supports?
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
    end

    private

    KEY_ACCOUNT_ACCESS_KEY = 'account-access-key'.freeze

    KEY_ACCOUNT_NAME = 'account-name'.freeze

    KEY_HOST_NAME = 'host-name'.freeze

    KEY_NAME = 'application_name'.freeze

    KEY_PORT = 'port'.freeze

    KEY_SSL_ENABLED = 'ssl-enabled'.freeze

    SERVICE_NAME = /app-dynamics/.freeze

    def account_access_key(credentials)
      account_access_key = credentials[KEY_ACCOUNT_ACCESS_KEY]
      "-Dappdynamics.agent.accountAccessKey=#{account_access_key}" if account_access_key
    end

    def account_name(credentials)
      account_name = credentials[KEY_ACCOUNT_NAME]
      "-Dappdynamics.agent.accountName=#{account_name}" if account_name
    end

    def app_dynamics_home
      @application.component_directory 'app-dynamics'
    end

    def host_name(credentials)
      host_name = credentials[KEY_HOST_NAME]
      fail "'#{KEY_HOST_NAME}' credential must be set" unless host_name
      "-Dappdynamics.controller.hostName=#{host_name}"
    end

    def port(credentials)
      port = credentials[KEY_PORT]
      "-Dappdynamics.controller.port=#{port}" if port
    end

    def ssl_enabled(credentials)
      ssl_enabled = credentials[KEY_SSL_ENABLED]
      "-Dappdynamics.controller.ssl.enabled=#{ssl_enabled}" if ssl_enabled
    end

  end

end
