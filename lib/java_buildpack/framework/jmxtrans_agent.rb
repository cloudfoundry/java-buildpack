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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Jmxtrans support.
    class JmxtransAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']

        raise_if_credentials_missing(credentials)

        graphite_host(credentials[HOST_KEY])
        graphite_port(credentials[PORT_KEY])
        graphite_prefix(credentials[PREFIX_KEY])

        @droplet.java_opts.add_preformatted_options("-javaagent:#{jar_path}=#{config_path}")
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['enabled'] && @application.services.one_service?(FILTER, HOST_KEY, PORT_KEY)
      end

      private

      FILTER = /jmxtrans/

      HOST_KEY = 'host'.freeze
      PORT_KEY = 'port'.freeze
      PREFIX_KEY = 'jmxtrans_prefix'.freeze

      private_constant :FILTER, :HOST_KEY, :PORT_KEY, :PREFIX_KEY

      def raise_if_credentials_missing(credentials)
        missing_keys = [HOST_KEY, PORT_KEY, PREFIX_KEY].select { |key| credentials[key].nil? }.map { |key| "'#{key}'" }
        raise "#{missing_keys.join(', ')} credentials must be set" unless missing_keys.empty?
      end

      def graphite_host(host_value)
        @droplet.java_opts.add_system_property('graphite.host', host_value)
      end

      def graphite_port(port_value)
        @droplet.java_opts.add_system_property('graphite.port', port_value)
      end

      def graphite_prefix(prefix_value)
        graphite_prefix = "#{prefix_value}#{app_name}.${CF_INSTANCE_INDEX}"
        @droplet.java_opts.add_system_property('graphite.prefix', graphite_prefix)
      end

      def app_name
        @application.details['application_name']
      end

      def jar_path
        qualify_path(@droplet.sandbox + jar_name, @droplet.root)
      end

      def config_path
        qualify_path(@droplet.sandbox + 'jmxtrans-agent.xml', @droplet.root)
      end
    end
  end
end
