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

require 'java_buildpack/framework'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/play/play_directory_locator'

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
      @auto_reconfiguration_version, @auto_reconfiguration_uri = PlayAutoReconfiguration.find_auto_reconfiguration(@app_dir, @configuration)
    end

    # Detects whether this application is suitable for auto-reconfiguration
    #
    # @return [String] returns +play-auto-reconfiguration-<version>+ if the application is a candidate for
    #                  auto-reconfiguration otherwise returns +nil+
    def detect
      @auto_reconfiguration_version ? id(@auto_reconfiguration_version) : nil
    end

    # Downloads the Auto-reconfiguration JAR
    #
    # @return [void]
    def compile
      download_auto_reconfiguration
    end

    # Does nothing
    #
    # @return [void]
    def release
    end

    private

    PLAY_APPLICATION_CONFIGURATION_DIRECTORY = 'conf'.freeze

    PLAY_APPLICATION_CONFIGURATION_FILE = 'application.conf'.freeze

    def download_auto_reconfiguration
      download_start_time = Time.now
      print "-----> Downloading Auto Reconfiguration #{@auto_reconfiguration_version} from #{@auto_reconfiguration_uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@auto_reconfiguration_uri) do |file| # TODO Use global cache #50175265
        system "cp #{file.path} #{File.join(@lib_directory, jar_name(@auto_reconfiguration_version))}"
        puts "(#{(Time.now - download_start_time).duration})"
      end

    end

    def self.find_auto_reconfiguration(app_dir, configuration)
      if JavaBuildpack::Util::Play.locate_play_application app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
      else
        version = nil
        uri = nil
      end

      return version, uri
    rescue => e
      raise RuntimeError, "Play Auto Reconfiguration framework error: #{e.message}", e.backtrace
    end

    def id(version)
      "play-auto-reconfiguration-#{version}"
    end

    def jar_name(version)
      "#{id version}.jar"
    end

  end

end
