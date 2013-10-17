# Encoding: utf-8
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

require 'java_buildpack/util'
require 'java_buildpack/util/shell'

module JavaBuildpack::Util

  # Base class for Play application classes.
  class BasePlayApp
    include JavaBuildpack::Util::Shell

    # Returns the version of this Play application
    #
    # @return [String, nil] the version of the Play application
    attr_reader :version

    # Determines whether the given application directory contains a Play application that this class recognizes.
    #
    # @param [String] app_dir the application directory
    # @return [Boolean] +true+ if and only if this class recognizes a Play application
    def self.recognizes?(app_dir)
      find_root app_dir
    end

    # Creates a Play application based on the given application directory.
    #
    # @param [String] app_dir the application directory
    def initialize(app_dir)
      @app_dir = app_dir
    end

    # Ensures this Play application is executable.
    def set_executable
      shell "chmod +x #{start_script}"
    end

    # Replaces the bootstrap class of this Play application.
    #
    # @param [String] bootstrap_class the replacement bootstrap class name
    def replace_bootstrap(bootstrap_class)
      update_file start_script, /play\.core\.server\.NettyServer/, bootstrap_class
    end

    # Adds the given JARs to this Play application's classpath.
    #
    # @param [Array<String>] libs the JAR paths
    def add_libs_to_classpath(libs)
      fail "Method 'add_libs_to_classpath' must be defined"
    end

    # Returns the path of the Play start script relative to the application directory.
    #
    # @return [String] the path of the Play start script relative to the application directory
    def start_script_relative
      "./#{Pathname.new(start_script).relative_path_from(Pathname.new(@app_dir)).to_s}"
    end

    # Determines whether or not the Play application contains a JAR with the given, possibly wildcarded, name.
    #
    # @param [Object] jar_name a JAR name which may contain +*+ to match zero or more characters, e.g. +a*.jar+
    # @return [Boolean] true if and only if at least one JAR was found matching the given name
    def contains?(jar_name)
      lib = File.join self.class.classpath_directory(play_root), jar_name
      Dir[lib].first
    end

    # Decorates the given Java options as appropriate to the version of Play.
    #
    # @param [Array<String>] java_opts the Java options to be decorated
    # @return [Array<String] the decorated Java options
    def decorate_java_opts(java_opts)
      java_opts
    end

    protected

    # Finds the Play application root directory, in the given application directory, containing a start script
    # and a Play JAR in the appropriate directory. Also finds the Play application version.
    #
    # @param [String] app_dir the application directory
    # @return [String, nil] the Play application root directory or +nil+ if no such directory was found
    # @return [String, nil] the Play application version or +nil+ if no version is available
    def self.root_and_version(app_dir)
      play_root = find_root(app_dir)
      fail "Unrecognized Play application in #{app_dir}" unless play_root
      version = version(classpath_directory_play_jar(play_root))
      fail "Unrecognized Play application version in #{app_dir}" unless version
      return play_root, version # rubocop:disable RedundantReturn
    end

    # The location of the directory containing the JARs of a Play application
    #
    # @param [String] root the root of the Play application
    # @return [String] the path to the directory containing the JARs
    def self.classpath_directory(root)
      File.join root, 'lib'
    end

    # The version of the Play application, as derived from the version number embedded in the name of the +play_+ JAR.
    #
    # @param [String] play_jar the path to the play JAR
    # @return [String, nil] the version of the Play application
    def self.version(play_jar)
      play_jar.match(/.*play_.*-(.*)\.jar/)[1]
    end

    # Returns the path of the start script.
    #
    # @return [String] the path of the start script
    def start_script
      self.class.start_script play_root
    end

    # Returns the path of the start script.
    #
    # @param [String] app_dir the application root
    # @return [String] the path of the start script
    def self.start_script(app_dir)
      fail "Method 'start_script' must be defined"
    end

    private

    PLAY_JAR = '*play_*-*.jar'.freeze

    attr_reader :app_dir

    def self.find_root(app_dir)
      roots = Dir[app_dir, File.join(app_dir, '*')].select do |file|
        start_script(file) && classpath_directory_play_jar(file)
      end

      fail "Play application detected in multiple directories: #{roots}" if roots.size > 1

      roots.first
    end

    def self.play_jar(root)
      Dir[File.join(root, PLAY_JAR)].first
    end

    def self.classpath_directory_play_jar(root)
      play_jar(classpath_directory(root))
    end

    def update_file(file_name, pattern, replacement)
      content = File.open(file_name, 'r') { |file| file.read }
      result = content.gsub! pattern, replacement

      File.open(file_name, 'w') do |file|
        file.write content
        file.fsync
      end

      result
    end

    attr_reader :play_root

  end

end
