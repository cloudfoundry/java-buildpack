# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
        credentials = @application.services.find_service(FILTER, %w[agent_manager_url url])['credentials']
        java_opts   = @droplet.java_opts

        java_opts
          .add_javaagent(agent_jar)
          .add_system_property('com.wily.introscope.agentProfile', agent_profile)
          .add_system_property('introscope.agent.hostName', agent_host_name)
          .add_system_property('com.wily.introscope.agent.agentName', agent_name(credentials))
          .add_system_property('introscope.agent.defaultProcessName', default_process_name(credentials))

        if agent_manager_credential(credentials)
          java_opts.add_system_property('agentManager.credential', agent_manager_credential(credentials))
        end

        add_url(credentials, java_opts)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, %w[agent_manager_url url]
      end

      private

      FILTER = /introscope/

      private_constant :FILTER

      def agent_host_name
        @application.details['application_uris'][0]
      end

      def agent_jar
        @droplet.sandbox + 'Agent.jar'
      end

      def add_url(credentials, java_opts)
        agent_manager = agent_manager_url(credentials)

        host, port, socket_factory = parse_url(agent_manager)
        java_opts.add_system_property('agentManager.url.1', agent_manager)
        java_opts.add_system_property('introscope.agent.enterprisemanager.transport.tcp.host.DEFAULT', host)
        java_opts.add_system_property('introscope.agent.enterprisemanager.transport.tcp.port.DEFAULT', port)
        java_opts.add_system_property('introscope.agent.enterprisemanager.transport.tcp.socketfactory.DEFAULT',
                                      socket_factory)
      end

      # Parse the agent manager url, split first by '://', and then with ':'
      # components is of the format [host, port, socket_factory]
      def parse_url(url)
        components = url.split('://')
        components.unshift('') if components.length == 1
        components[1] = components[1].split(':')
        components.flatten!
        components.push(protocol_mapping(components[0]))
        components.shift
        components
      end

      def agent_name(credentials)
        credentials['agent_name'] || @configuration['default_agent_name']
      end

      def agent_profile
        @droplet.sandbox + 'core/config/IntroscopeAgent.profile'
      end

      def default_process_name(credentials)
        credentials['agent_default_process_name'] || @application.details['application_name']
      end

      def protocol_mapping(protocol)
        socket_factory_base = 'com.wily.isengard.postofficehub.link.net.'

        protocol_socket_factory = {
          ''      => socket_factory_base + 'DefaultSocketFactory',
          'ssl'   => socket_factory_base + 'SSLSocketFactory',
          'http'  => socket_factory_base + 'HttpTunnelingSocketFactory',
          'https' => socket_factory_base + 'HttpsTunnelingSocketFactory'
        }

        protocol_socket_factory[protocol] || protocol
      end

      def agent_manager_url(credentials)
        credentials['agent_manager_url'] || credentials['url']
      end

      def agent_manager_credential(credentials)
        credentials['agent_manager_credential'] || credentials['credential']
      end
    end
  end
end
