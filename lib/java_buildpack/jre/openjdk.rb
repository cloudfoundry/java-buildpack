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
require 'java_buildpack/jre/details'
require 'java_buildpack/jre/memory/memory_heuristics_openjdk_pre8'
require 'java_buildpack/jre/memory/memory_heuristics_openjdk'
require 'java_buildpack/jre/tokenized_version'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'

module JavaBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
      @details = Details.new(@configuration)
    end

    # Detects which version of Java this application should use.  *NOTE:* This method will always return _some_ value,
    # so it should only be used once that application has already been established to be a Java application.
    #
    # @return [String, nil] returns +jre-<vendor>-<version>+.
    def detect
      memory_sizes # drive out errors early
      id @details
    end

    # Downloads and unpacks a JRE
    #
    # @return [void]
    def compile
      memory_sizes # drive out errors early
      application_cache = JavaBuildpack::Util::ApplicationCache.new

      download_start_time = Time.now
      print "-----> Downloading #{@details.vendor} #{@details.version} JRE from #{@details.uri} "

      application_cache.get(id(@details), @details.uri) do |file|
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
    end

    # Build Java memory options and places then in +context[:java_opts]+
    #
    # @return [void]
    def release
      memory_sizes.each do |memory_size|
        @java_opts << memory_size
      end
    end

    private

    HEAP_SIZE = 'java.heap.size'.freeze

    JAVA_HOME = '.java'.freeze

    PERMGEN_SIZE = 'java.permgen.size'.freeze

    METASPACE_SIZE = 'java.metaspace.size'.freeze

    STACK_SIZE = 'java.stack.size'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "-----> Expanding JRE to #{JAVA_HOME} "

      java_home = File.join @app_dir, JAVA_HOME
      system "rm -rf #{java_home}"
      system "mkdir -p #{java_home}"
      system "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def id(details)
      "jre-#{details.vendor}-#{details.version}"
    end

    def memory_sizes
      java_options = []

      if TokenizedVersion.new(@details.version) < TokenizedVersion.new("1.8")
        specified_memory_sizes = {}
        specified_memory_sizes['heap'] = @configuration[HEAP_SIZE]
        specified_memory_sizes['permgen'] = @configuration[PERMGEN_SIZE]
        specified_memory_sizes['stack'] = @configuration[STACK_SIZE]
        mh = MemoryHeuristicsOpenJDKPre8.new(specified_memory_sizes)
        java_options << "-Xmx#{mh.heap}"
        java_options << "-XX:MaxPermSize=#{mh.permgen}"
        java_options << "-Xss#{mh.stack}"
      else
        specified_memory_sizes = {}
        specified_memory_sizes['heap'] = @configuration[HEAP_SIZE]
        specified_memory_sizes['metaspace'] = @configuration[METASPACE_SIZE]
        specified_memory_sizes['stack'] = @configuration[STACK_SIZE]
        mh = MemoryHeuristicsOpenJDK.new(specified_memory_sizes)
        java_options << "-Xmx#{mh.heap}"
        java_options << "-XX:MaxMetaspaceSize=#{mh.metaspace}"
        java_options << "-Xss#{mh.stack}"
      end

      java_options
    end

  end

end
