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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_utils'
require 'java_buildpack/logging/logger_factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat Internal Proxies support.
    class TomcatInternalProxies < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect; end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless supports?

        mutate_server if @configuration.key?('regex')
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def add_proxies(server)
        valve = REXML::XPath.match(server, '//Valve[@className="org.apache.catalina.valves.RemoteIpValve"]').first
        valve.add_attribute 'internalProxies', @configuration['regex']
      end

      def formatter
        formatter         = REXML::Formatters::Pretty.new(4)
        formatter.compact = true
        formatter
      end

      def mutate_server
        puts '       Adding Internal Proxies'

        document = read_xml server_xml
        server   = REXML::XPath.match(document, '/Server').first

        add_proxies server

        write_xml server_xml, document
      end

    end

  end
end
