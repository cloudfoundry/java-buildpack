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

require 'java_buildpack/framework'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/download'
require 'java_buildpack/util/play_utils'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Play
  # applications. Note that Spring auto-reconfiguration is covered by the SpringAutoReconfiguration framework.
  # The reconfiguration performed here is to override Play application configuration to bind a Play application to
  # cloud resources.
  class PlayAutoReconfiguration

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @app_dir = context[:app_dir]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
      @version, @uri = PlayAutoReconfiguration.find_auto_reconfiguration(@app_dir, @configuration)
    end

    # Detects whether this application is suitable for auto-reconfiguration
    #
    # @return [String] returns +play-auto-reconfiguration-<version>+ if the application is a candidate for
    #                  auto-reconfiguration otherwise returns +nil+
    def detect
      @version ? id(@version) : nil
    end

    # Downloads the Auto-reconfiguration JAR
    #
    # @return [void]
    def compile
      JavaBuildpack::Util.download(@version, @uri, 'Auto Reconfiguration', jar_name(@version), @lib_directory)
    end

    # Does nothing
    #
    # @return [void]
    def release
    end

    private

      def self.find_auto_reconfiguration(app_dir, configuration)
        if JavaBuildpack::Util::PlayUtils.root app_dir
          version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
        else
          version = nil
          uri = nil
        end

        return version, uri # rubocop:disable RedundantReturn
      end

      def id(version)
        "play-auto-reconfiguration-#{version}"
      end

      def jar_name(version)
        "#{id version}.jar"
      end

  end

end
