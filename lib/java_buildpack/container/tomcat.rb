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
require 'java_buildpack/component/base_component'
require 'java_buildpack/container'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Tomcat applications.
  class Tomcat < JavaBuildpack::Component::BaseComponent

    # Creates an instance
    #
    # @param [Hash] context a collection of utilities used the component
    def initialize(context)
      super(context)

      if supports?
        @tomcat_version, @tomcat_uri = JavaBuildpack::Repository::ConfiguredItem
        .find_item(@component_name, @configuration) { |candidate_version| candidate_version.check_size(3) }

        @lifecycle_version, @lifecycle_uri = JavaBuildpack::Repository::ConfiguredItem
        .find_item(@component_name, @configuration['lifecycle_support'])

        @logging_version, @logging_uri = JavaBuildpack::Repository::ConfiguredItem
        .find_item(@component_name, @configuration['logging_support'])
      else
        @tomcat_version, @tomcat_uri       = nil, nil
        @lifecycle_version, @lifecycle_uri = nil, nil
        @logging_version, @logging_uri     = nil, nil
      end
    end

    # @macro base_component_detect
    def detect
      if @tomcat_version && @lifecycle_version && @logging_version
        [tomcat_id(@tomcat_version), lifecycle_id(@lifecycle_version), logging_id(@logging_version)]
      else
        nil
      end
    end

    # @macro base_component_compile
    def compile
      download_tomcat
      download_lifecycle
      download_logging
      link_to(@application.root.children, root)
      do_not_depend_on_this
      @droplet.additional_libraries << tomcat_datasource_jar if tomcat_datasource_jar.exist?
      @droplet.additional_libraries.link_to web_inf_lib
    end

    # @macro base_component_release
    def release
      @droplet.java_opts.add_system_property 'http.port', '$PORT'

      [
          @droplet.java_home.as_env_var,
          @droplet.java_opts.as_env_var,
          "$PWD/#{(@droplet.sandbox + 'bin/catalina.sh').relative_path_from(@droplet.root)}",
          'run'
      ].compact.join(' ')
    end

    protected

    # The unique identifier of the component, incorporating the version of the dependency (e.g. +tomcat=7.0.42+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def tomcat_id(version)
      "#{Tomcat.to_s.dash_case}=#{version}"
    end

    # The unique identifier of the component, incorporating the version of the dependency (e.g.
    # +tomcat-lifecycle-support=1.1.0+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def lifecycle_id(version)
      "tomcat-lifecycle-support=#{version}"
    end

    # The unique identifier of the component, incorporating the version of the dependency (e.g.
    # +tomcat-logging-support=1.1.0+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def logging_id(version)
      "tomcat-logging-support=#{version}"
    end

    # Whether or not this component supports this application
    #
    # @return [Boolean] whether or not this component supports this application
    def supports?
      web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)
    end

    private

    def container_libs_directory
      @droplet.root + '.spring-insight/container-libs'
    end

    # DO NOT DEPEND ON THIS FUNCTIONALITY
    def do_not_depend_on_this
      link_to(container_libs_directory.children, tomcat_lib) if container_libs_directory.exist?
      link_to(extra_applications_directory.children, webapps) if extra_applications_directory.exist?
    end

    def download_tomcat
      download(@tomcat_version, @tomcat_uri) { |file| expand file }
    end

    def download_lifecycle
      download_jar(@lifecycle_version, @lifecycle_uri, lifecycle_jar_name, @droplet.sandbox + 'lib',
                   'Tomcat Lifecycle Support')
    end

    def download_logging
      download_jar(@logging_version, @logging_uri, logging_jar_name, @droplet.sandbox + 'endorsed',
                   'Tomcat Logging Support')
    end

    def expand(file)
      with_timing "Expanding Tomcat to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
        FileUtils.mkdir_p @droplet.sandbox
        shell "tar xzf #{file.path} -C #{@droplet.sandbox} --strip 1 --exclude webapps 2>&1"

        @droplet.copy_resources
      end
    end

    def extra_applications_directory
      @droplet.root + '.spring-insight/extra-applications'
    end

    def link_to(source, destination)
      FileUtils.mkdir_p destination
      source.each { |path| (destination + path.basename).make_symlink(path.relative_path_from(destination)) }
    end

    def root
      webapps + 'ROOT'
    end

    def lifecycle_jar_name
      "tomcat_lifecycle_support-#{@lifecycle_version}.jar"
    end

    def logging_jar_name
      "tomcat_logging_support-#{@logging_version}.jar"
    end

    def tomcat_datasource_jar
      tomcat_lib + 'tomcat-jdbc.jar'
    end

    def tomcat_lib
      @droplet.sandbox + 'lib'
    end

    def webapps
      @droplet.sandbox + 'webapps'
    end

    def web_inf_lib
      @droplet.root + 'WEB-INF/lib'
    end

    def web_inf?
      (@application.root + 'WEB-INF').exist?
    end

  end

end
