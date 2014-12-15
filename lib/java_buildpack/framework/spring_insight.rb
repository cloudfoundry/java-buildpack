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
        @version, @uri, @agent_id, @agent_pass = supports? ? find_insight_agent : [nil, nil, nil, nil]
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version ? id(@version) : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Spring Insight download location is always accessible') do
          # TODO: AGENT_DOWNLOAD_URI_SUFFIX To be removed once the full path is included in VCAP_SERVICES see #58873498
          download(@version, @uri.chomp('/') + AGENT_DOWNLOAD_URI_SUFFIX) { |file| expand file }
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
          .add_javaagent(weaver_jar)
          .add_system_property('insight.base', insight_directory)
          .add_system_property('insight.logs', logs_directory)
          .add_system_property('aspectj.overweaving', true)
          .add_system_property('org.aspectj.tracing.factory', 'default')
          .add_system_property('insight.transport.type', 'HTTP')

        add_agent_configuration
      end

      protected

      # The unique identifier of the component, incorporating the version of the dependency (e.g.
      # +spring-insight=1.9.3+)
      #
      # @param [String] version the version of the dependency
      # @return [String] the unique identifier of the component
      def id(version)
        "#{SpringInsight.to_s.dash_case}=#{version}"
      end

      private

      # TODO: To be removed once the full path is included in VCAP_SERVICES see issue 58873498
      AGENT_DOWNLOAD_URI_SUFFIX = '/services/config/agent-download'.freeze

      FILTER = /insight/.freeze

      private_constant :AGENT_DOWNLOAD_URI_SUFFIX, :FILTER

      def add_agent_configuration
        @droplet.java_opts
          .add_system_property('agent.http.protocol', 'http')
          .add_system_property('agent.http.host', URI(@uri).host)
          .add_system_property('agent.http.port', 80)
          .add_system_property('agent.http.context.path', 'insight')
          .add_system_property('agent.http.username', @agent_id)
          .add_system_property('agent.http.password', @agent_pass)
          .add_system_property('agent.http.send.json', false)
          .add_system_property('agent.http.use.proxy', false)
      end

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

        agent_dir
      end

      def install_insight(agent_dir)
        root = Pathname.glob(agent_dir + 'springsource-insight-uber-agent-*')[0]

        init_container_libs root
        init_insight_cloudfoundry_agent_plugin root
        init_insight root
        init_insight_agent_plugins root
        init_weaver root
      end

      def init_container_libs(root)
        move container_libs_directory,
             root + 'agents/common/insight-bootstrap-generic-*.jar',
             root + 'agents/tomcat/7/lib/insight-bootstrap-tomcat-common-*.jar',
             root + 'agents/tomcat/7/lib/insight-agent-*.jar'
      end

      def init_insight(root)
        move insight_directory,
             root + 'insight/collection-plugins',
             root + 'insight/conf'
      end

      def init_insight_agent_plugins(root)
        move insight_directory + 'agent-plugins',
             root + 'transport/http/insight-agent-http-*.jar',
             root + 'cloudfoundry/insight-agent-cloudfoundry-*.jar'
      end

      def init_insight_cloudfoundry_agent_plugin(root)
        move container_libs_directory,
             root + 'cloudfoundry/cloudfoundry-runtime-*.jar'
      end

      def init_weaver(root)
        move weaver_directory,
             root + 'cloudfoundry/insight-weaver-*.jar'
      end

      def container_libs_directory
        @droplet.root + '.spring-insight/container-libs'
      end

      def find_insight_agent
        service     = @application.services.find_service FILTER
        version     = service['label'].match(/(.*)-(.*)/)[2]
        credentials = service['credentials']
        uri         = credentials['dashboard_url']
        id          = credentials['agent_username']
        pass        = credentials['agent_password']
        [version, uri, id, pass]
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
        @application.services.one_service? FILTER, 'dashboard_url', 'agent_username', 'agent_password'
      end

      def uber_agent_zip(location)
        candidates = Pathname.glob(location + 'springsource-insight-uber-agent-*.zip')
        fail 'There was not exactly one Uber Agent zip' if candidates.size != 1
        candidates[0]
      end

      def weaver_directory
        @droplet.sandbox + 'weaver'
      end

      def weaver_jar
        (weaver_directory + 'insight-weaver-*.jar').glob[0]
      end

    end
  end
end
