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
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Play applications.
  class Play

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
      @start_script_path = File.join(@app_dir, PLAY_START_SCRIPT)
    end

    # Detects whether this application is a Play application.
    #
    # @return [String] returns +Play+ if and only if the application has a +start+ script, otherwise
    #                  returns +nil+
    def detect
      play_app? ? PLAY_TAG : nil
    end

    # Makes the +start+ script executable.
    #
    # @return [void]
    def compile
      `chmod +x #{@start_script_path}`
    end

    # Creates the command to run the Play application.
    #
    # @return [String] the command to run the application.
    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"
      "PATH=#{@java_home}/bin:$PATH JAVA_HOME=#{@java_home} ./#{PLAY_START_SCRIPT} #{java_opts}"
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    PLAY_START_SCRIPT = 'start'.freeze

    PLAY_TAG = 'Play'.freeze

    PLAY_JAR_PATTERN = 'lib/play.play_*.jar'.freeze

    def play_app?
      File.exists?(@start_script_path) && !File.directory?(@start_script_path) &&
          !Dir.glob(File.join(@app_dir, PLAY_JAR_PATTERN)).empty?
    end

    def java_opts
      @java_opts.compact.sort.join(' ')
    end

  end

end
