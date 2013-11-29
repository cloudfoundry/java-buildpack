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

require 'java_buildpack/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/service_utils'
require 'tmpdir'
require 'fileutils'
require 'uri'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling Insight auto configuration.
  class SpringInsight < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Spring Insight', context)
      @version, @uri = supports? ? find_insight_agent : [nil, nil]

      FileUtils.mkdir_p container_libs_directory
      FileUtils.mkdir_p extra_applications_directory
    end

    def detect
      @version ? id(@version) : nil
    end

    def compile
      download(@version, @uri.chomp('/') + AGENT_DOWNLOAD_URI_SUFFIX) { |file| expand file } # TODO: AGENT_DOWNLOAD_URI_SUFFIX To be removed once the full path is included in VCAP_SERVICES see issue 58873498
    end

    def release
      @application.java_opts
      .add_javaagent(weaver_jar)
      .add_system_property('insight.base', insight_directory)
      .add_system_property('insight.logs', logs_directory)
      .add_system_property('aspectj.overweaving', true)
      .add_system_property('org.aspectj.tracing.factory', 'default')
      .add_system_property('insight.transport.type', 'HTTP')

      add_agent_configuration
    end

    protected

    # The unique identifier of the component, incorporating the version of the dependency (e.g. +spring-insight=1.9.3+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def id(version)
      "spring-insight=#{version}"
    end

    def supports?
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
    end

    private

    AGENT_DOWNLOAD_URI_SUFFIX = '/services/config/agent-download'.freeze # TODO: To be removed once the full path is included in VCAP_SERVICES see issue 58873498

    NAME_KEY = 'application_name'.freeze

    SERVICE_NAME = /insight/.freeze

    def add_agent_configuration
      @application.java_opts
      .add_system_property('agent.http.protocol', 'http')
      .add_system_property('agent.http.host', URI(@uri).host)
      .add_system_property('agent.http.port', 80)
      .add_system_property('agent.http.context.path', 'insight')
      .add_system_property('agent.http.username', 'spring')
      .add_system_property('agent.http.password', 'insight')
      .add_system_property('agent.http.send.json', false)
      .add_system_property('agent.http.use.proxy', false)
      .add_system_property('agent.name.override', "'#{@vcap_application[NAME_KEY]}'")
    end

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding Spring Insight to #{@application.relative_path_to home} "

      Dir.mktmpdir do |root|
        agent_dir = unpack_agent_installer(Pathname.new(root), file)
        install_insight(agent_dir)
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def unpack_agent_installer(root, file)
      installer_dir = root + 'installer'
      agent_dir = root + 'agent'

      FileUtils.mkdir_p(installer_dir)
      FileUtils.mkdir_p(agent_dir)
      shell "unzip -qq #{file.path} -d #{installer_dir} 2>&1"
      shell "unzip -qq #{uber_agent_zip(installer_dir)} -d #{agent_dir} 2>&1"

      agent_dir
    end

    def install_insight(agent_dir)
      FileUtils.rm_rf home
      FileUtils.mkdir_p home

      root = Pathname.glob(agent_dir + 'springsource-insight-uber-agent-*')[0]

      init_container_libs root
      init_extra_applications root
      init_insight root
      init_insight_analyzer root
      init_weaver root
    end

    def init_container_libs(root)
      move container_libs_directory,
           root + 'agents/common/insight-bootstrap-generic-*.jar',
           root + 'agents/tomcat/7/lib/insight-bootstrap-tomcat-common-*.jar'
    end

    def init_extra_applications(root)
      move extra_applications_directory,
           root + 'insight-agent'
    end

    def init_insight(root)
      move insight_directory,
           root + 'insight/collection-plugins',
           root + 'insight/conf'
    end

    def init_insight_analyzer(root)
      move insight_analyzer_directory + 'WEB-INF/lib',
           root + 'transport/http/insight-agent-http-*.jar'
    end

    def init_weaver(root)
      move weaver_directory,
           root + 'agents/common/insight-weaver-*.jar'
    end

    def container_libs_directory
      @application.component_directory 'container-libs'
    end

    def extra_applications_directory
      @application.component_directory 'extra-applications'
    end

    def find_insight_agent
      service = JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
      version = service['label'].match(/(.*)-(.*)/)[2]
      uri = service['credentials']['dashboard_url']

      return version, uri # rubocop:disable RedundantReturn
    end

    def insight_analyzer_directory
      extra_applications_directory + 'insight-agent'
    end

    def insight_directory
      home + 'insight'
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

    def uber_agent_zip(location)
      candidates = Pathname.glob(location + 'springsource-insight-uber-agent-*.zip')
      fail 'There was not exactly one Uber Agent zip' if candidates.size != 1
      candidates[0]
    end

    def weaver_directory
      home + 'weaver'
    end

    def weaver_jar
      Pathname.glob(home + 'weaver/insight-weaver-*.jar')[0]
    end

  end

end
