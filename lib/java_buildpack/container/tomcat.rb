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
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @tomcat_version, @tomcat_uri = Tomcat.find_tomcat(@app_dir, @configuration)
      @support_version, @support_uri = Tomcat.find_support(@app_dir, @configuration)
    end

    # Detects whether this application is a Tomcat application.
    #
    # @return [String] returns +tomcat-<version>+ if and only if the application has a +WEB-INF+ directory, otherwise
    #                  returns +nil+
    def detect
      @tomcat_version ? [tomcat_id(@tomcat_version), tomcat_support_id(@support_version)] : nil
    end

    # Downloads and unpacks a Tomcat instance and support JAR
    #
    # @return [void]
    def compile
      download_tomcat
      download_support
      link_application
      link_libs
    end

    # Creates the command to run the Tomcat application.
    #
    # @return [String] the command to run the application.
    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      start_script_string = ContainerUtils.space(File.join TOMCAT_HOME, 'bin', 'catalina.sh')

      "#{java_home_string}#{java_opts_string}#{start_script_string} run"
    end

    private

      KEY_HTTP_PORT = 'http.port'.freeze

      KEY_SUPPORT = 'support'.freeze

      RESOURCES = File.join('..', '..', '..', 'resources', 'tomcat').freeze

      TOMCAT_HOME = '.tomcat'.freeze

      WEB_INF_DIRECTORY = 'WEB-INF'.freeze

      def copy_resources(tomcat_home)
        resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
        system "cp -r #{File.join resources, '*'} #{tomcat_home}"
      end

      def download_tomcat
        download_start_time = Time.now
        print "-----> Downloading Tomcat #{@tomcat_version} from #{@tomcat_uri} "

        JavaBuildpack::Util::ApplicationCache.new.get(@tomcat_uri) do |file|  # TODO: Use global cache #50175265
          puts "(#{(Time.now - download_start_time).duration})"
          expand(file, @configuration)
        end
      end

      def download_support
        download_start_time = Time.now
        print "       Downloading Buildpack Tomcat Support #{@support_version} from #{@support_uri} "

        JavaBuildpack::Util::ApplicationCache.new.get(@support_uri) do |file|  # TODO: Use global cache #50175265
          system "cp #{file.path} #{File.join(tomcat_home, 'lib', support_jar_name(@support_version))}"
          puts "(#{(Time.now - download_start_time).duration})"
        end
      end

      def expand(file, configuration)
        expand_start_time = Time.now
        print "       Expanding Tomcat to #{TOMCAT_HOME} "

        system "rm -rf #{tomcat_home}"
        system "mkdir -p #{tomcat_home}"
        system "tar xzf #{file.path} -C #{tomcat_home} --strip 1 --exclude webapps --exclude #{File.join 'conf', 'server.xml'} --exclude #{File.join 'conf', 'context.xml'} 2>&1"

        copy_resources tomcat_home
        puts "(#{(Time.now - expand_start_time).duration})"
      end

      def self.find_tomcat(app_dir, configuration)
        if web_inf? app_dir
          version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
            fail "Malformed Tomcat version #{candidate_version}: too many version components" if candidate_version[3]
          end
        else
          version = nil
          uri = nil
        end

        return version, uri # rubocop:disable RedundantReturn
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

        return version, uri # rubocop:disable RedundantReturn
      end

      def tomcat_id(version)
        "tomcat-#{version}"
      end

      def tomcat_support_id(version)
        "tomcat-buildpack-support-#{version}"
      end

      def link_application
        system "rm -rf #{root}"
        system "mkdir -p #{webapps}"
        system "ln -sfn #{File.join '..', '..'} #{root}"
      end

      def link_libs
        libs = ContainerUtils.libs(@app_dir, @lib_directory)

        if libs
          FileUtils.mkdir_p(web_inf_lib) unless File.exists?(web_inf_lib)
          libs.each { |lib| system "ln -sfn #{File.join '..', '..', lib} #{web_inf_lib}" }
        end
      end

      def root
        File.join webapps, 'ROOT'
      end

      def support_jar_name(version)
        "#{tomcat_support_id version}.jar"
      end

      def tomcat_home
        File.join @app_dir, TOMCAT_HOME
      end

      def webapps
        File.join tomcat_home, 'webapps'
      end

      def web_inf_lib
        File.join root, 'WEB-INF', 'lib'
      end

      def self.web_inf?(app_dir)
        File.exists? File.join(app_dir, WEB_INF_DIRECTORY)
      end

  end

end
