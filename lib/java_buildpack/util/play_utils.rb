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

require 'java_buildpack/util'

module JavaBuildpack::Util

  # Utilities for dealing with Play Framework application
  class PlayUtils

    # Locate a Play application root directory in the given application directory.
    #
    # @param [String] app_dir the application directory
    # @return [Dir, nil] the located Play application directory or `nil` if there is no such
    # @raise if more than one Play application directory is located
    def self.root(app_dir)

      # A Play application may reside directly in the application directory or in a direct subdirectory of the
      # application directory.
      roots = Dir[app_dir, File.join(app_dir, '*')].select do |file|
        start_script(file) && (lib_play_jar(file) || staged_play_jar(file))
      end

      fail "Play application detected in multiple directories: #{roots}" if roots.size > 1

      roots.first
    end

    # The location of the start script in a Play application
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the path to the start script, or +nil+ if it does not exist
    def self.start_script(root)
      Dir[File.join(root, START_SCRIPT)].first
    end

    # The location of the lib directory in a dist Play application
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the path to the lib directory, or +nil+ if it does not exist
    def self.lib(root)
      File.join root, 'lib'
    end

    # The location of the play JAR in a dist Play application
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the path to the dist play JAR, or +nil+ if it does not exist
    def self.lib_play_jar(root)
      play_jar(lib(root))
    end

    # The location of the staged directory in a staged Play application
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the path to the staged directory, or +nil+ if it does not exist
    def self.staged(root)
      File.join root, 'staged'
    end

    # The location of the play JAR in a staged Play application
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the path to the staged play JAR, or +nil+ if it does not exist
    def self.staged_play_jar(root)
      play_jar(staged(root))
    end

    # The version of the Play application, as derived from the version number embedded in the name of the +play_+ JAR.
    #
    # @param [String] root the root of the Play application
    # @return [String, nil] the version of the Play application
    def self.version(root)
      play_jar = lib_play_jar(root) || staged_play_jar(root)
      play_jar.match(/.*play_(.*)\.jar/)[1]
    end

    private

    START_SCRIPT = 'start'.freeze

    PLAY_JAR = '*play_*.jar'.freeze

    def self.play_jar(root)
      Dir[File.join(root, PLAY_JAR)].first
    end

    private_class_method :new

  end

end
