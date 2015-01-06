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

require 'fileutils'
require 'zip'
require 'find'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK-like JRE.
    class OpenJDKLike < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = self.class.to_s.space_case
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @droplet.java_home.root = @droplet.sandbox
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        version                        = required_java_version
        version_specific_configuration = { KEY_REPOSITORY_ROOT => @configuration[KEY_REPOSITORY_ROOT],
                                           KEY_VERSION         => version }

        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                                         version_specific_configuration)
        @droplet.java_home.version = @version
        super
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
          .add_option('-XX:OnOutOfMemoryError', killjava)
          .concat memory
      end

      private

      KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

      KEY_MEMORY_SIZES = 'memory_sizes'.freeze

      KEY_DETECT_COMPILED_VERSION = 'detect_compiled'.freeze

      KEY_JAVA_EIGHT_VERSION = 8.freeze

      KEY_JAVA_SEVEN_VERSION = 7.freeze

      KEY_JAVA_SIX_VERSION = 6.freeze

      KEY_REPOSITORY_ROOT = 'repository_root'.freeze

      KEY_VERSION = 'version'.freeze

      CAFEBABE = 'cafebabe'.freeze

      private_constant :KEY_MEMORY_HEURISTICS, :KEY_MEMORY_SIZES, :KEY_DETECT_COMPILED_VERSION,
                       :KEY_JAVA_SEVEN_VERSION, :KEY_JAVA_SIX_VERSION, :KEY_VERSION, :CAFEBABE

      def killjava
        @droplet.sandbox + 'bin/killjava.sh'
      end

      def java_6?(version_code)
        version_code == 32
      end

      def java_7?(version_code)
        version_code == 33
      end

      def java_6_or_java_7?(version_code)
        java_6?(version_code) || java_7?(version_code)
      end

      def required_java_version
        version_configuration = @configuration[KEY_VERSION]
        detected_version      = resolved_version_code version_configuration

        if java_6? detected_version
          version = version_configuration[KEY_JAVA_SIX_VERSION]
        elsif java_7? detected_version
          version = version_configuration[KEY_JAVA_SEVEN_VERSION]
        else
          version = version_configuration[KEY_JAVA_EIGHT_VERSION]
        end
        version
      end

      def resolved_version_code(configuration)
        configuration[KEY_DETECT_COMPILED_VERSION] == 'enabled' ? detect_compiled_version(@application.root) : 34
      end

      # If no valid files are found with 'cafebabe' and an expected version code then
      # the code '34' for Java 8 will be returned.
      def detect_compiled_version(application_root)
        result = 0
        Find.find(application_root.to_path) do |sub_entry|
          result = check_file(sub_entry, result) if sub_entry.end_with? '.class' unless FileTest.directory?(sub_entry)
        end
        result == 0 ? 34 : result
      end

      def check_file(entry, result)
        bits   = File.open(entry).read.unpack('H*')[0]
        logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger OpenJDKLike
        logger.debug "Scanning '#{entry}', first 8 bits are '#{bits[0, 8]}' and the version code is '#{bits[14, 2]}'."
        result = [result, Integer(bits[14, 2])].max if bits[0, 8] == CAFEBABE
        result
      end

      def memory
        sizes      = @configuration[KEY_MEMORY_SIZES] ? @configuration[KEY_MEMORY_SIZES].clone : {}
        heuristics = @configuration[KEY_MEMORY_HEURISTICS] ? @configuration[KEY_MEMORY_HEURISTICS].clone : {}

        version_configuration = @configuration[KEY_VERSION]
        detected_version      = resolved_version_code version_configuration

        if java_6_or_java_7? detected_version
          heuristics.delete 'metaspace'
          sizes.delete 'metaspace'
        else
          heuristics.delete 'permgen'
          sizes.delete 'permgen'
        end

        OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
      end

    end

  end
end
