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

require 'fileutils'
require 'java_buildpack/base_component'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/util/resource_utils'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Tomcat applications.
  class Tomcat < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Tomcat', context)

      if supports?
        @tomcat_version, @tomcat_uri = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, @configuration) { |candidate_version| candidate_version.check_size(3) }
        @support_version, @support_uri = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, @configuration[KEY_SUPPORT])
      else
        @tomcat_version, @tomcat_uri = nil, nil
        @support_version, @support_uri = nil, nil
      end
    end

    def detect
      @tomcat_version && @support_version ? [tomcat_id(@tomcat_version), support_id(@support_version)] : nil
    end

    def compile
      download_tomcat
      download_support
      link_tomcat_datasource
      link_application
      link_container_libs
      link_extra_applications
      link_libs
    end

    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      start_script_string = ContainerUtils.space(@application.relative_path_to(tomcat_home + 'bin' + 'catalina.sh'))

      "#{java_home_string}#{java_opts_string}#{start_script_string} run"
    end

    protected

    # The unique identifier of the component, incorporating the version of the dependency (e.g. +tomcat=7.0.42+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def tomcat_id(version)
      "#{@parsable_component_name}=#{version}"
    end

    # The unique identifier of the component, incorporating the version of the dependency (e.g. +tomcat-buildpack-support=1.1.0+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def support_id(version)
      "tomcat-buildpack-support=#{version}"
    end

    # Whether or not this component supports this application
    #
    # @return [Boolean] whether or not this component supports this application
    def supports?
      web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@app_dir)
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    KEY_SUPPORT = 'support'.freeze

    TOMCAT_DATASOURCE_JAR = 'tomcat-jdbc.jar'.freeze

    WEB_INF_DIRECTORY = 'WEB-INF'.freeze

    def container_libs_directory
      @application.component_directory 'container-libs'
    end

    def download_tomcat
      download(@tomcat_version, @tomcat_uri) { |file| expand file }
    end

    def download_support
      download_jar(@support_version, @support_uri, support_jar_name, File.join(tomcat_home, 'lib'), 'Buildpack Tomcat Support')
    end

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding Tomcat to #{@application.relative_path_to(tomcat_home)} "

      FileUtils.rm_rf tomcat_home
      FileUtils.mkdir_p tomcat_home
      shell "tar xzf #{file.path} -C #{tomcat_home} --strip 1 --exclude webapps --exclude #{File.join 'conf', 'server.xml'} --exclude #{File.join 'conf', 'context.xml'} 2>&1"

      JavaBuildpack::Util::ResourceUtils.copy_resources('tomcat', tomcat_home)
      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def extra_applications_directory
      @application.component_directory 'extra-applications'
    end

    def link_application
      FileUtils.rm_rf root
      FileUtils.mkdir_p root
      @application.children.each { |child| FileUtils.ln_sf child.relative_path_from(root), root }
    end

    # Support for container libs in addition to the user's application is temporary and will go away in the future.
    def link_container_libs
      if container_libs_directory.exist?
        container_libs = ContainerUtils.libs(@app_dir, container_libs_directory)

        if container_libs
          FileUtils.mkdir_p(tomcat_lib) unless tomcat_lib.exist?
          container_libs.each { |lib| FileUtils.ln_sf(File.join('..', '..', lib), tomcat_lib) }
        end
      end
    end

    # Support for extra applications in addition to the user's application is temporary and will go away in the future.
    def link_extra_applications
      if extra_applications_directory.exist?
        extra_applications = ContainerUtils.relative_paths(@app_dir, extra_applications_directory.children) { |file| file.directory? }

        if extra_applications
          FileUtils.mkdir_p webapps
          extra_applications.each { |extra_application| FileUtils.ln_sf(File.join('..', '..', extra_application), webapps) }
        end
      end
    end

    def link_libs
      libs = ContainerUtils.libs(@app_dir, @lib_directory)

      if libs
        FileUtils.mkdir_p(web_inf_lib) unless web_inf_lib.exist?
        libs.each { |lib| FileUtils.ln_sf(File.join('..', '..', lib), web_inf_lib) }
      end
    end

    def link_tomcat_datasource
      tomcat_datasource_jar = tomcat_lib + TOMCAT_DATASOURCE_JAR
      if tomcat_datasource_jar.exist?
        # Link Tomcat datasource JAR into .lib
        lib_directory_pathname = Pathname.new(@lib_directory)
        symlink_source = tomcat_datasource_jar.relative_path_from(lib_directory_pathname)
        symlink_target = lib_directory_pathname + TOMCAT_DATASOURCE_JAR
        symlink_target.make_symlink symlink_source
      end
    end

    def root
      webapps + 'ROOT'
    end

    def support_jar_name
      "tomcat-buildpack-support-#{@support_version}.jar"
    end

    def tomcat_home
      @application.component_directory 'tomcat'
    end

    def tomcat_lib
      tomcat_home + 'lib'
    end

    def webapps
      tomcat_home + 'webapps'
    end

    def web_inf_lib
      root + 'WEB-INF' + 'lib'
    end

    def web_inf?
      @application.child(WEB_INF_DIRECTORY).exist?
    end

  end

end
