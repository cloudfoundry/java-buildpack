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
      download_zip false
    end

    def release
      credentials = JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)['credentials']
      java_opts = @application.java_opts

      java_opts
      .add_javaagent(home + 'javaagent.jar')
      .add_system_property('appdynamics.agent.applicationName', "'#{@vcap_application[KEY_NAME]}'")
      .add_system_property('appdynamics.agent.tierName', "'#{@configuration['tier_name']}'")
      .add_system_property('appdynamics.agent.nodeName',
                           "$(expr \"$VCAP_APPLICATION\" : '.*instance_id[\": ]*\"\\([a-z0-9]\\+\\)\".*')")

      account_access_key(java_opts, credentials)
      account_name(java_opts, credentials)
      host_name(java_opts, credentials)
      port(java_opts, credentials)
      ssl_enabled(java_opts, credentials)
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

    def account_access_key(java_opts, credentials)
      account_access_key = credentials[KEY_ACCOUNT_ACCESS_KEY]
      java_opts.add_system_property 'appdynamics.agent.accountAccessKey', account_access_key if account_access_key
    end

    def account_name(java_opts, credentials)
      account_name = credentials[KEY_ACCOUNT_NAME]
      java_opts.add_system_property 'appdynamics.agent.accountName', account_name if account_name
    end

    def host_name(java_opts, credentials)
      host_name = credentials[KEY_HOST_NAME]
      fail "'#{KEY_HOST_NAME}' credential must be set" unless host_name
      java_opts.add_system_property 'appdynamics.controller.hostName', host_name
    end

    def port(java_opts, credentials)
      port = credentials[KEY_PORT]
      java_opts.add_system_property 'appdynamics.controller.port', port if port
    end

    def ssl_enabled(java_opts, credentials)
      ssl_enabled = credentials[KEY_SSL_ENABLED]
      java_opts.add_system_property 'appdynamics.controller.ssl.enabled', ssl_enabled if ssl_enabled
    end

  end

end
