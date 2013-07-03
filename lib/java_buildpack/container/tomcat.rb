# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

require 'uri'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Tomcat applications.
  class Tomcat

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @tomcat_version, @tomcat_uri = Tomcat.find_tomcat(@app_dir, @configuration)
      @support_version, @support_uri = Tomcat.find_support(@app_dir, @configuration)
    end

    # Detects whether this application is a Tomcat application.
    #
    # @return [String] returns +tomcat-<version>+ if and only if the application has a +WEB-INF+ directory, otherwise
    #                  returns +nil+
    def detect
      @tomcat_version ? id(@tomcat_version) : nil
    end

    # Downloads and unpacks a Tomcat instance
    #
    # @return [void]
    def compile
      download_tomcat
      download_support
      link_application
    end

    # Creates the command to run the Tomcat application.
    #
    # @return [String] the command to run the application.
    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"
      java_opts_string = ContainerUtils.to_java_opts_s(@java_opts)

      "JAVA_HOME=#{@java_home} JAVA_OPTS=\"#{java_opts_string}\" #{TOMCAT_HOME}/bin/catalina.sh run"
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    KEY_SUPPORT = 'support'.freeze

    RESOURCES = '../../../resources/tomcat'.freeze

    TOMCAT_HOME = '.tomcat'.freeze

    WEB_INF_DIRECTORY = 'WEB-INF'.freeze

    def copy_resources(tomcat_home)
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      system "cp -r #{resources}/* #{tomcat_home}"
    end

    def download_tomcat
      download_start_time = Time.now
      print "-----> Downloading Tomcat #{@tomcat_version} from #{@tomcat_uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@tomcat_uri) do |file|  # TODO Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        expand(file, @configuration)
      end
    end

    def download_support
      download_start_time = Time.now
      print "-----> Downloading Buildpack Tomcat Support #{@support_version} from #{@support_uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@support_uri) do |file|  # TODO Use global cache #50175265
        system "cp #{file.path} #{tomcat_home}/lib/tomcat-buildpack-support.jar"
        puts "(#{(Time.now - download_start_time).duration})"
      end
    end

    def expand(file, configuration)
      expand_start_time = Time.now
      print "-----> Expanding Tomcat to #{TOMCAT_HOME} "

      system "rm -rf #{tomcat_home}"
      system "mkdir -p #{tomcat_home}"
      system "tar xzf #{file.path} -C #{tomcat_home} --strip 1 --exclude webapps --exclude conf/server.xml --exclude conf/context.xml 2>&1"

      copy_resources tomcat_home
      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_tomcat(app_dir, configuration)
      if web_inf? app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |version|
          raise "Malformed Tomcat version #{version}: too many version components" if version[3]
        end
      else
        version = nil
        uri = nil
      end

      return version, uri
    rescue => e
      raise RuntimeError, "Tomcat container error: #{e.message}", e.backtrace
    end

    def self.find_support(app_dir, configuration)
      if web_inf? app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration[KEY_SUPPORT])
      else
        version = nil
        uri = nil
      end

      return version, uri
    end

    def id(version)
      "tomcat-#{version}"
    end

    def link_application
      webapps = "#{tomcat_home}/webapps"
      root = "#{webapps}/ROOT"

      system "rm -rf #{root}"
      system "mkdir -p #{webapps}"
      system "ln -s ../.. #{root}"
    end

    def tomcat_home
      File.join @app_dir, TOMCAT_HOME
    end

    def self.web_inf?(app_dir)
      File.exists? File.join(app_dir, WEB_INF_DIRECTORY)
    end

  end

end
