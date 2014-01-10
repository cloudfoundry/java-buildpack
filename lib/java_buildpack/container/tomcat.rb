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

    def initialize(context)
      super(context)

      if supports?
        @tomcat_version, @tomcat_uri   = JavaBuildpack::Repository::ConfiguredItem
        .find_item(@component_name, @configuration) { |candidate_version| candidate_version.check_size(3) }
        @support_version, @support_uri = JavaBuildpack::Repository::ConfiguredItem
        .find_item(@component_name, @configuration['support'])
      else
        @tomcat_version, @tomcat_uri   = nil, nil
        @support_version, @support_uri = nil, nil
      end
    end

    def detect
      @tomcat_version && @support_version ? [tomcat_id(@tomcat_version), support_id(@support_version)] : nil
    end

    def compile
      download_tomcat
      download_support
      link_to(@application.root.children, root)
      do_not_depend_on_this
      @droplet.additional_libraries << tomcat_datasource_jar if tomcat_datasource_jar.exist?
      @droplet.additional_libraries.link_to web_inf_lib
    end

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

    def download_support
      download_jar(@support_version, @support_uri, support_jar_name, @droplet.sandbox + 'lib',
                   'Buildpack Tomcat Support')
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

    def support_jar_name
      "tomcat_buildpack_support-#{@support_version}.jar"
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
