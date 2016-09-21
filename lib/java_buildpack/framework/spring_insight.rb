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

require 'java_buildpack/component/base_component'
require 'java_buildpack/util/cache/internet_availability'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'
require 'tmpdir'
require 'fileutils'
require 'uri'

module JavaBuildpack
  module Framework

    # Encapsulates the detect, compile, and release functionality for enabling Insight auto configuration.
    class SpringInsight < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @version, @uri, @agent_transport = find_insight_agent if supports?
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version ? id(@version) : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Spring Insight download location is always accessible'
        ) do
          download(@version, @uri) { |file| expand file }
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_javaagent(weaver_jar)
          .add_system_property('insight.base', insight_directory)
          .add_system_property('insight.logs', logs_directory)
          .add_system_property('aspectj.overweaving', true)
          .add_system_property('org.aspectj.tracing.factory', 'default')
      end

      protected

      # The unique identifier of the component, incorporating the version of the dependency)
      #
      # @param [String] version the version of the dependency
      # @return [String] the unique identifier of the component
      def id(version)
        "#{SpringInsight.to_s.dash_case}=#{version}"
      end

      private

      FILTER = /p-insight/

      private_constant :FILTER

      def expand(file)
        with_timing "Expanding Spring Insight to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
          Dir.mktmpdir do |root|
            agent_dir = unpack_agent_installer(Pathname.new(root), file)
            install_insight(agent_dir)
          end
        end
      end

      def unpack_agent_installer(root, file)
        installer_dir = root + 'installer'
        agent_dir     = root + 'agent'

        FileUtils.mkdir_p(installer_dir)
        FileUtils.mkdir_p(agent_dir)
        shell "unzip -qq #{file.path} -d #{installer_dir} 2>&1"
        shell "unzip -qq #{uber_agent_zip(installer_dir)} -d #{agent_dir} 2>&1"
        move agent_dir,
             installer_dir + 'answers.properties',
             installer_dir + 'agent.override.properties'

        agent_dir
      end

      def install_insight(agent_dir)
        root = Pathname.glob(agent_dir + 'springsource-insight-uber-agent-*')[0]

        init_insight root
        init_insight_properties agent_dir
        init_insight_agent_plugins root
        init_weaver root
      end

      def init_insight(root)
        move insight_directory,
             root + 'insight/collection-plugins',
             root + 'insight/conf',
             root + 'insight/bootstrap',
             root + 'insight/extras'
      end

      def init_insight_properties(root)
        move insight_directory,
             root + 'agent.override.properties'

        answers_properties = root + 'answers.properties'
        insight_properties = insight_directory + 'conf/insight.properties'
        system "cat #{answers_properties} >> #{insight_properties}"
      end

      def init_insight_agent_plugins(root)
        move insight_directory + 'agent-plugins',
             root + 'agents/tomcat/7/lib/insight-agent-*.jar'
        transport_jar = transport_plugin root
        move insight_directory + 'agent-plugins', transport_jar
      end

      def init_weaver(root)
        move weaver_directory,
             root + 'cloudfoundry/insight-weaver-*.jar'
      end

      def find_insight_agent
        service     = @application.services.find_service FILTER
        credentials = service['credentials']
        version     = credentials['version'] || '1.0.0'
        uri         = credentials['agent_download_url']
        transport   = credentials['agent_transport'] || 'rabbitmq'
        [version, uri, transport]
      end

      def insight_directory
        @droplet.sandbox + 'insight'
      end

      def logs_directory
        insight_directory + 'logs'
      end

      def move(destination, *globs)
        FileUtils.mkdir_p destination

        globs.each do |glob|
          FileUtils.mv Pathname.glob(glob)[0], destination
        end
      end

      def supports?
        @application.services.one_service? FILTER, 'agent_download_url', 'service_instance_id'
      end

      def uber_agent_zip(location)
        candidates = Pathname.glob(location + 'springsource-insight-uber-agent-*.zip')
        raise 'There was not exactly one Uber Agent zip' if candidates.size != 1
        candidates[0]
      end

      def weaver_directory
        @droplet.sandbox + 'weaver'
      end

      def weaver_jar
        (weaver_directory + 'insight-weaver-*.jar').glob[0]
      end

      def transport_plugin(root)
        return root + 'transport/http/insight-agent-http-*.jar' if http_transport?
        return root + 'transport/rabbitmq/insight-agent-rabbitmq-*.jar' if rabbit_transport?
        (root + 'transport/activemq/insight-agent-activemq-*.jar') if active_transport?
      end

      def http_transport?
        @agent_transport.eql? 'http'
      end

      def rabbit_transport?
        @agent_transport.eql? 'rabbitmq'
      end

      def active_transport?
        @agent_transport.eql? 'activemq'
      end

    end

  end
end
