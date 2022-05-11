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

require 'shellwords'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Elastic APM support.
    class ElasticApmAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
      end

      # Modifies the application's runtime configuration. The component is expected to transform members of the
      # +context+ # (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the
      # component.
      #
      # Container components are also expected to create the command required to run the application.  These components
      # are expected to read the +context+ values and take them into account when creating the command.
      #
      # @return [void, String] components other than containers and JREs are not expected to return any value.
      #                        Container and JRE components are expected to return a command required to run the
      #                        application.
      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials   = @application.services.find_service(FILTER, [SERVER_URLS, SECRET_TOKEN])['credentials']
        java_opts     = @droplet.java_opts
        configuration = {}

        apply_configuration(credentials, configuration)
        apply_user_configuration(credentials, configuration)
        write_java_opts(java_opts, configuration)

        java_opts.add_javaagent(@droplet.sandbox + jar_name)
                 .add_system_property('elastic.apm.home', @droplet.sandbox)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [SERVER_URLS, SECRET_TOKEN]
      end

      private

      FILTER = /elastic-apm/.freeze

      BASE_KEY = 'elastic.apm.'

      SERVER_URLS = 'server_urls'

      SECRET_TOKEN = 'secret_token'

      SERVICE_NAME = 'service_name'

      private_constant :FILTER, :SERVER_URLS, :BASE_KEY, :SECRET_TOKEN

      def apply_configuration(credentials, configuration)
        configuration['log_file_name'] = 'STDOUT'
        configuration[SERVER_URLS]     = credentials[SERVER_URLS]
        configuration[SECRET_TOKEN]    = credentials[SECRET_TOKEN]
        configuration[SERVICE_NAME]    = @application.details['application_name']
      end

      def apply_user_configuration(credentials, configuration)
        credentials.each do |key, value|
          configuration[key] = value
        end
      end

      def write_java_opts(java_opts, configuration)
        configuration.each do |key, value|
          if /\$[({][^)}]+[)}]/ =~ value.to_s
            # we need \" because this is a system property which ends up inside `JAVA_OPTS` which is already quoted
            java_opts.add_system_property("elastic.apm.#{key}", "\\\"#{value}\\\"")
          else
            java_opts.add_system_property("elastic.apm.#{key}", Shellwords.escape(value))
          end
        end
      end

    end
  end
end
