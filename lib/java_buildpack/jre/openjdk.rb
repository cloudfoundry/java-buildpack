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
require 'java_buildpack/util/tokenized_version'
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

      download_start_time = Time.now
      print "-----> Downloading #{@details.vendor} #{@details.version} JRE from #{@details.uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(id(@details), @details.uri) do |file|  # TODO Use global cache #50175265
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

    PROPERTY_MAPPING = {HEAP_SIZE => 'heap', STACK_SIZE => 'stack', PERMGEN_SIZE => 'permgen', METASPACE_SIZE => 'metaspace'}

    SWITCHES = {'heap' => '-Xmx', 'stack' => '-Xss', 'metaspace' => '-XX:MaxMetaspaceSize=', 'permgen' => '-XX:MaxPermSize='}

    def rename(input, renaming)
      renamed = {}
      input.each_pair do |k, v|
        renamed_key = renaming[k]
        renamed[renamed_key] = v if renamed_key
      end
      renamed
    end

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
      specified_memory_sizes = rename(@configuration, PROPERTY_MAPPING)
      heuristic_class = pre_8 ? MemoryHeuristicsOpenJDKPre8 : MemoryHeuristicsOpenJDK
      java_options(heuristic_class.new(specified_memory_sizes).output)
    end

    def pre_8
      @details.version < JavaBuildpack::Util::TokenizedVersion.new("1.8.0")
    end

    def java_options(memory_values)
      java_options = []

      rename(memory_values, SWITCHES).each_pair do |switch, memory_value|
        java_options << "#{switch}#{memory_value}"
      end

      java_options
    end

  end

end
