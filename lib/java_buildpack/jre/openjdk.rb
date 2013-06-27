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

require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/memory_heuristics_openjdk_pre8'
require 'java_buildpack/jre/memory/memory_heuristics_openjdk'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @diagnostics_dir = context[:diagnostics][:directory]
      @version, @uri = OpenJdk.find_openjdk(@configuration)

      context[:java_home].concat JAVA_HOME
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +openjdk-<version>+.
    def detect
      id @version
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      download_start_time = Time.now
      print "-----> Downloading OpenJDK #{@version} JRE from #{@uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@uri) do |file|  # TODO Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
      copy_resources
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      @java_opts << "-XX:OnOutOfMemoryError=$HOME/buildpack-diagnostics/killjava"
      @java_opts.concat memory(@configuration)
    end

    private

    RESOURCES = '../../../resources/openjdk/diagnostics'.freeze

    JAVA_HOME = '.java'.freeze

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'

    KEY_MEMORY_SIZES = 'memory_sizes'

    def expand(file)
      expand_start_time = Time.now
      print "-----> Expanding JRE to #{JAVA_HOME} "

      system "rm -rf #{java_home}"
      system "mkdir -p #{java_home}"
      system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_openjdk(configuration)
      JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
    rescue => e
      raise RuntimeError, "OpenJDK JRE error: #{e.message}", e.backtrace
    end

    def id(version)
      "openjdk-#{version}"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def memory(configuration)
      heuristics = configuration[KEY_MEMORY_HEURISTICS] || {}
      sizes = configuration[KEY_MEMORY_SIZES] || {}

      heuristic_class = pre_8 ? MemoryHeuristicsOpenJDKPre8 : MemoryHeuristicsOpenJDK
      heuristic_class.new(sizes, heuristics).resolve
    end

    def pre_8
      @version < JavaBuildpack::Util::TokenizedVersion.new("1.8.0")
    end

    def copy_resources
      resources = File.expand_path(RESOURCES, File.dirname(__FILE__))
      system "cp -r #{resources}/* #{@diagnostics_dir}/."
    end

  end

end
