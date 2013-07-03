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

require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
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
      @play_root = Play.play_root @app_dir
    end

    # Detects whether this application is a Play application.
    #
    # @return [String] returns +Play+ if and only if the application has a +start+ script, otherwise
    #                  returns +nil+
    def detect
      @play_root ? 'play' : nil
    end

    # Makes the +start+ script executable.
    #
    # @return [void]
    def compile
      system "chmod +x #{Play.start_script @play_root}"
      link_libs
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

    START_SCRIPT = 'start'.freeze

    PLAY_JAR = 'play*.jar'.freeze

    def self.play_root(app_dir)
      roots = Dir[app_dir, File.join(app_dir, '*')].select do |file|
        start_script(file) && (lib_play_jar(file) || staged_play_jar(file))
      end

      raise "Play application detected in multiple directories: #{roots}" if roots.size > 1
      roots.first
    end

    def self.lib(root)
      File.join root, 'lib'
    end

    def self.lib_play_jar(root)
      play_jar(lib(root))
    end

    def link_libs
      libs = ContainerUtils.libs(@app_dir, @lib_directory)

      if libs
        lib_target = [Play.lib(@play_root), Play.staged(@play_root)].find { |target| Play.play_jar(target) }
        libs.each { |lib| system "ln -s #{File.join '..', lib} #{lib_target}" }
      end
    end

    def self.staged(root)
      File.join root, 'staged'
    end

    def self.staged_play_jar(root)
      play_jar(staged(root))
    end

    def self.play_jar(root)
      Dir[File.join(root, PLAY_JAR)].first
    end

    def self.start_script(root)
      Dir[File.join(root, START_SCRIPT)].first
    end

    def start_script_relative(app_dir, play_root)
      Pathname.new(Play.start_script(play_root)).relative_path_from(Pathname.new(app_dir)).to_s
    end

  end

end
