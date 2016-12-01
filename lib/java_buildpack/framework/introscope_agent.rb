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
require 'java_buildpack/util/to_b'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Introscope support.
    class IntroscopeAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + 'Agent.jar')
        java_opts.add_system_property('com.wily.introscope.agentProfile',
                                      @droplet.sandbox + 'core/config/IntroscopeAgent.profile')

        agent_host_name java_opts
        agent_name java_opts, credentials
        default_process_name java_opts
        host_name java_opts, credentials
        port java_opts, credentials
        ssl_socket_factory java_opts, credentials
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'host-name'
      end

      private

      FILTER = /introscope/

      private_constant :FILTER

      def agent_host_name(java_opts)
        java_opts.add_system_property('introscope.agent.hostName', @application.details['application_uris'][0])
      end

      def agent_name(java_opts, credentials)
        name = credentials['agent-name'] || @configuration['default_agent_name']
        java_opts.add_system_property('com.wily.introscope.agent.agentName', name.to_s)
      end

      def default_process_name(java_opts)
        java_opts.add_system_property('introscope.agent.defaultProcessName', @application.details['application_name'])
      end

      def host_name(java_opts, credentials)
        host_name = credentials['host-name']
        raise "'host-name' credential must be set" unless host_name
        java_opts.add_system_property 'introscope.agent.enterprisemanager.transport.tcp.host.DEFAULT', host_name
      end

      def port(java_opts, credentials)
        port = credentials['port']
        java_opts.add_system_property 'introscope.agent.enterprisemanager.transport.tcp.port.DEFAULT', port if port
      end

      def ssl_socket_factory(java_opts, credentials)
        ssl = credentials['ssl'].to_b
        java_opts.add_system_property 'introscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT',
                                      'com.wily.isengard.postofficehub.link.net.SSLSocketFactory' if ssl
      end

    end
  end
end
