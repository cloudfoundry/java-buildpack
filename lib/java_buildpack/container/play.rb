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

require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/play_utils'
require 'pathname'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Play applications.
  class Play

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
      @play_root = JavaBuildpack::Util::PlayUtils.root(@app_dir)
    end

    # Detects whether this application is a Play application.
    #
    # @return [String] returns +Play+ if and only if the application has a +start+ script, otherwise
    #                  returns +nil+
    def detect
      @play_root ? id(JavaBuildpack::Util::PlayUtils.version(@play_root)) : nil
    end

    # Makes the +start+ script executable.
    #
    # @return [void]
    def compile
      system "chmod +x #{JavaBuildpack::Util::PlayUtils.start_script @play_root}"
      add_libs_to_classpath @play_root
      replace_bootstrap @play_root
    end

    # Creates the command to run the Play application.
    #
    # @return [String] the command to run the application.
    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      path_string = "PATH=#{File.join @java_home, 'bin'}:$PATH"
      java_home_string = ContainerUtils.space("JAVA_HOME=#{@java_home}")
      start_script_string = ContainerUtils.space(start_script_relative @app_dir, @play_root)
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@java_opts))

      "#{path_string}#{java_home_string}#{start_script_string}#{java_opts_string}"
    end

    private

      KEY_HTTP_PORT = 'http.port'.freeze

      def add_libs_to_classpath(root)
        if JavaBuildpack::Util::PlayUtils.lib_play_jar(root)
          # Dist applications either list JARs in a classpath variable (e.g. in Play 2.1.3) or on a -cp parameter (e.g. in Play 2.0),
          # so add to the appropriate list.
          script_dir_relative_path = Pathname.new(@app_dir).relative_path_from(Pathname.new(@play_root)).to_s

          additional_classpath = ContainerUtils.libs(@app_dir, @lib_directory).map do |lib|
            "$scriptdir/#{script_dir_relative_path}/#{lib}"
          end

          result = update_file JavaBuildpack::Util::PlayUtils.start_script(root), /^classpath=\"(.*)\"$/, "classpath=\"#{additional_classpath.join(':')}:\\1\""
          unless result
            ContainerUtils.libs(@app_dir, @lib_directory).each do |lib|
              system "ln -nsf ../../#{lib} #{JavaBuildpack::Util::PlayUtils.lib root}"
            end
          end
        else
          # Staged applications add all the JARs in the staged directory to the classpath, so add symbolic links to the staged directory.
          ContainerUtils.libs(@app_dir, @lib_directory).each do |lib|
            system "ln -nsf ../#{lib} #{JavaBuildpack::Util::PlayUtils.staged root}"
          end
        end
      end

      def id(version)
        "play-#{version}"
      end

      def replace_bootstrap(root)
        update_file JavaBuildpack::Util::PlayUtils.start_script(root), /play\.core\.server\.NettyServer/, 'org.cloudfoundry.reconfiguration.play.Bootstrap'
      end

      def start_script_relative(app_dir, play_root)
        "./#{Pathname.new(JavaBuildpack::Util::PlayUtils.start_script(play_root)).relative_path_from(Pathname.new(app_dir)).to_s}"
      end

      def update_file(file_name, pattern, replacement)
        content = File.open(file_name, 'r') { |file| file.read }
        result = content.gsub! pattern, replacement
        File.open(file_name, 'w') { |file| file.write content }
        result
      end

  end

end
