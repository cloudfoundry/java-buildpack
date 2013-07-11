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
require 'java_buildpack/util/play/play_directory_locator'
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
      @play_root = JavaBuildpack::Util::Play.locate_play_application(@app_dir)
    end

    # Detects whether this application is a Play application.
    #
    # @return [String] returns +Play+ if and only if the application has a +start+ script, otherwise
    #                  returns +nil+
    def detect
      @play_root ? id(version(@play_root)) : nil
    end

    # Makes the +start+ script executable.
    #
    # @return [void]
    def compile
      system "chmod +x #{Play.start_script @play_root}"
      add_libs_to_classpath
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

    def id(version)
      "play-#{version}"
    end

    def self.lib(root)
      File.join root, 'lib'
    end

    def self.lib_play_jar(root)
      play_jar(lib(root))
    end

    def add_libs_to_classpath
      script_dir_relative_path = Pathname.new(@app_dir).relative_path_from(Pathname.new(@play_root)).to_s

      additional_classpath = ContainerUtils.libs(@app_dir, @lib_directory).map do |lib|
        "$scriptdir/#{script_dir_relative_path}/#{lib}"
      end

      start_script = File.join(@play_root, START_SCRIPT)
      start_script_content = File.open(start_script, 'r') { |file| file.read }
      start_script_content.gsub! /^classpath=\"(.*)\"$/, "classpath=\"#{additional_classpath.join(':')}:\\1\""
      File.open(start_script, 'w') { |file| file.write start_script_content }
    end

    def self.staged(root)
      File.join root, 'staged'
    end

    def self.staged_play_jar(root)
      play_jar(staged(root))
    end

    def self.play_jar(root)
      Dir[File.join(root, PLAY_JAR)].find { |candidate| candidate =~ /.*play_[\d\-\.]*\.jar/ }
    end

    def self.start_script(root)
      root && File.directory?(root) ? Dir[File.join(root, START_SCRIPT)].first : false
    end

    def start_script_relative(app_dir, play_root)
      "./#{Pathname.new(Play.start_script(play_root)).relative_path_from(Pathname.new(app_dir)).to_s}"
    end

    def version(root)
      play_jar = Play.lib_play_jar(root) || Play.staged_play_jar(root)
      play_jar.match(/.*play_(.*)\.jar/)[1]
    end

  end

end
