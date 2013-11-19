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
    end

    def detect
      @version ? id(@version) : nil
    end

    def compile
      download(@version, @uri.chomp('/') + AGENT_DOWNLOAD_URI_SUFFIX) { |file| expand file } # TODO: AGENT_DOWNLOAD_URI_SUFFIX To be removed once the full path is included in VCAP_SERVICES see issue 58873498
    end

    def release
      weaver_jar = @application.relative_path_to(Pathname.new Dir[File.join(insight_home, 'weaver', 'insight-weaver-*.jar')][0])

      @java_opts << "-javaagent:#{weaver_jar}"
      @java_opts << "-Dinsight.base=#{File.join INSIGHT_HOME, 'insight'}"
      @java_opts << "-Dinsight.logs=#{File.join INSIGHT_HOME, 'insight', 'logs'}"
      @java_opts << '-Daspectj.overweaving=true'
      @java_opts << '-Dorg.aspectj.tracing.factory=default'
      @java_opts << '-Dagent.http.protocol=http'
      @java_opts << "-Dagent.http.host=#{URI(@uri).host}"
      @java_opts << '-Dagent.http.port=80'
      @java_opts << '-Dagent.http.context.path=insight'
      @java_opts << '-Dagent.http.username=spring'
      @java_opts << '-Dagent.http.password=insight'
      @java_opts << '-Dagent.http.send.json=false'
      @java_opts << '-Dagent.http.use.proxy=false'
      @java_opts << '-Dinsight.transport.type=HTTP'
      @java_opts << "-Dagent.name.override=#{@vcap_application[NAME_KEY]}"
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

    EXTRA_APPLICATIONS_DIRECTORY = '.extra-applications'.freeze

    CONTAINER_LIBS_DIRECTORY = '.container-libs'.freeze

    INSIGHT_HOME = '.insight'.freeze

    NAME_KEY = 'application_name'.freeze

    SERVICE_NAME = /insight/.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding Spring Insight to #{INSIGHT_HOME} "

      Dir.mktmpdir do |root|
        agent_dir = unpack_agent_installer(root, file)
        install_insight(agent_dir)
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def unpack_agent_installer(root, file)
      installer_dir = File.join root, 'installer'
      agent_dir = File.join root, 'agent'

      FileUtils.mkdir_p(installer_dir)
      FileUtils.mkdir_p(agent_dir)
      shell "unzip -qq #{file.path} -d #{installer_dir} 2>&1"
      shell "unzip -qq #{uber_agent_zip(installer_dir)} -d #{agent_dir} 2>&1"

      agent_dir
    end

    def install_insight(agent_dir)
      weaver_directory = File.join insight_home, 'weaver'
      insight_directory = File.join insight_home, 'insight'
      insight_analyser_directory = File.join extra_applications_directory, 'insight-agent'
      uber_agent_directory = File.join agent_dir, 'springsource-insight-uber-agent-*'

      FileUtils.rm_rf insight_home
      FileUtils.rm_rf insight_analyser_directory
      FileUtils.mkdir_p container_libs_directory
      FileUtils.mkdir_p extra_applications_directory
      FileUtils.mkdir_p weaver_directory
      FileUtils.mkdir_p insight_directory

      shell "mv #{File.join uber_agent_directory, 'agents', 'common', 'insight-weaver-*.jar'} #{weaver_directory}"
      shell "mv #{File.join uber_agent_directory, 'agents', 'common', 'insight-bootstrap-generic-*.jar'} #{container_libs_directory}"
      shell "mv #{File.join uber_agent_directory, 'agents', 'tomcat', '7', 'lib', 'insight-bootstrap-tomcat-common-*.jar'} #{container_libs_directory}"
      shell "mv #{File.join uber_agent_directory, 'insight', 'collection-plugins'} #{insight_directory}"
      shell "mv #{File.join uber_agent_directory, 'insight', 'conf'} #{insight_directory}"
      shell "mv #{File.join uber_agent_directory, 'insight-agent'} #{insight_analyser_directory}"
      shell "mv #{File.join uber_agent_directory, 'transport', 'http', 'insight-agent-http-*.jar'} #{File.join insight_analyser_directory, 'WEB-INF', 'lib'} "
    end

    def container_libs_directory
      File.join @app_dir, CONTAINER_LIBS_DIRECTORY
    end

    def extra_applications_directory
      File.join @app_dir, EXTRA_APPLICATIONS_DIRECTORY
    end

    def uber_agent_zip(location)
      candidates = Dir[File.join location, 'springsource-insight-uber-agent-*.zip']
      fail 'There was not exactly one Uber Agent zip' if candidates.size != 1
      candidates[0]
    end

    def find_insight_agent
      service = JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
      version = service['label'].match(/(.*)-(.*)/)[2]
      uri = service['credentials']['dashboard_url']

      return version, uri # rubocop:disable RedundantReturn
    end

    def insight_home
      File.join @app_dir, INSIGHT_HOME
    end

  end

end
