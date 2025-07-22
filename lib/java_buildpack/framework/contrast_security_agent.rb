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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'
require 'rexml/document'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for running the Contrast Security Agent support.
    class ContrastSecurityAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger ContrastSecurityAgent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        # Fetch the credentials and settings
        credentials = @application.services.find_service(FILTER, API_KEY, SERVICE_KEY, TEAMSERVER_URL,
                                                         USERNAME)['credentials']

        # Add the Contrast config via env vars
        add_config_to_env credentials

        # Add the -javaagent option to cause the agent to start with the JVM
        @droplet.java_opts
                .add_preformatted_options("-javaagent:#{qualify_path(@droplet.sandbox + jar_name, @droplet.root)}")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#jar_name)
      def jar_name
        @version < INFLECTION_VERSION ? "contrast-engine-#{short_version}.jar" : "java-agent-#{short_version}.jar"
      end

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, API_KEY, SERVICE_KEY, TEAMSERVER_URL, USERNAME
      end

      private

      API_KEY = 'api_key'

      FILTER = 'contrast-security'

      INFLECTION_VERSION = JavaBuildpack::Util::TokenizedVersion.new('3.4.3').freeze

      PLUGIN_PACKAGE = 'com.aspectsecurity.contrast.runtime.agent.plugins'

      SERVICE_KEY = 'service_key'

      TEAMSERVER_URL = 'teamserver_url'

      USERNAME = 'username'

      private_constant :API_KEY, :FILTER, :INFLECTION_VERSION, :PLUGIN_PACKAGE, :SERVICE_KEY, :TEAMSERVER_URL,
                       :USERNAME

      def application_name
        @application.details['application_name'] || 'ROOT'
      end

      def appname_exist?
        @droplet.java_opts.any? do |java_opt|
          java_opt =~ /contrast\.override\.appname/ || java_opt =~ /contrast\.application\.name/
        end
      end

      def contrast_config
        @droplet.sandbox + 'contrast.config'
      end

      def short_version
        "#{@version[0]}.#{@version[1]}.#{@version[2]}"
      end

      # Add Contrast config to the env variables of the droplet.
      def add_config_to_env(credentials)
        env_vars = @droplet.environment_variables

        # Add any extra environment variables that start with CONTRAST__
        process_extra_env_vars credentials, env_vars

        # Add the config in the backwards compatible old format setting name
        add_env_var env_vars, 'CONTRAST__API__API_KEY', credentials[API_KEY]
        add_env_var env_vars, 'CONTRAST__API__SERVICE_KEY', credentials[SERVICE_KEY]
        add_env_var env_vars, 'CONTRAST__API__URL', "#{credentials[TEAMSERVER_URL]}/Contrast"
        add_env_var env_vars, 'CONTRAST__API__USER_NAME', credentials[USERNAME]

        add_env_var env_vars, 'CONTRAST__AGENT__CONTRAST_WORKING_DIR', '$TMPDIR'

        app_name = application_name
        add_env_var env_vars, 'CONTRAST__APPLICATION__NAME', app_name unless appname_exist?

        # Add the config for the proxy, if it exists
        add_proxy_config credentials, env_vars
      end

      # Add any generic new config from the broker, for any entry that starts with CONTRAST__ add to the env
      # The intention is to allow the broker to add any new config that it wants to, without needing to modify the
      # buildpack
      def process_extra_env_vars(credentials, env_vars)
        credentials.each do |key, value|
          # Add any that start with CONTRAST__ AND non-empty values
          matched = key.match?(/^CONTRAST__/) && !value.to_s.empty?
          add_env_var env_vars, key, value if matched
        end
      end

      def add_env_var(env_vars, key, value)
        env_vars.add_environment_variable key, value
      end

      def add_proxy_config(credentials, env_vars)
        host_set = credentials_value_set?(credentials, 'proxy_host')
        add_env_var env_vars, 'CONTRAST__API__PROXY__HOST', credentials['proxy_host'] if host_set

        port_set = credentials_value_set?(credentials, 'proxy_port')
        add_env_var env_vars, 'CONTRAST__API__PROXY__PORT', credentials['proxy_port'] if port_set

        pass_set = credentials_value_set?(credentials, 'proxy_pass')
        add_env_var env_vars, 'CONTRAST__API__PROXY__PASS', credentials['proxy_pass'] if pass_set

        user_set = credentials_value_set?(credentials, 'proxy_user')
        add_env_var env_vars, 'CONTRAST__API__PROXY__USER', credentials['proxy_user'] if user_set
      end

      def credentials_value_set?(credentials, key)
        !credentials[key].to_s.empty?
      end

    end

  end
end
