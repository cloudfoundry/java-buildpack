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
require 'find'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK-like JRE.
    class OpenJDKLike < JavaBuildpack::Component::VersionedDependencyComponent
      include Find

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = self.class.to_s.space_case
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]
        @logger         = JavaBuildpack::Logging::LoggerFactory.instance.get_logger OpenJDKLike

        @droplet.java_home.root = @droplet.sandbox
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        version       = detect_compiled?(@configuration[KEY_VERSION]) ? compiled_version(@application.root) : VERSION_8
        configuration = { KEY_REPOSITORY_ROOT => @configuration[KEY_REPOSITORY_ROOT],
                          KEY_VERSION         => @configuration[KEY_VERSION][version] }

        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, configuration)
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
        version = detect_compiled?(@configuration[KEY_VERSION]) ? compiled_version(@application.root) : VERSION_8

        @droplet.java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
          .add_option('-XX:OnOutOfMemoryError', killjava)
          .concat memory(version)
      end

      private

      CAFEBABE = 'cafebabe'.freeze

      KEY_DETECT_COMPILED_VERSION = 'detect_compiled'.freeze

      KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

      KEY_MEMORY_SIZES = 'memory_sizes'.freeze

      KEY_REPOSITORY_ROOT = 'repository_root'.freeze

      KEY_VERSION = 'version'.freeze

      VERSION_6 = 6.freeze

      VERSION_7 = 7.freeze

      VERSION_8 = 8.freeze

      private_constant :CAFEBABE, :KEY_DETECT_COMPILED_VERSION, :KEY_MEMORY_HEURISTICS, :KEY_MEMORY_SIZES,
                       :KEY_REPOSITORY_ROOT, :KEY_VERSION, :VERSION_6, :VERSION_7, :VERSION_8

      def class?(path)
        File.extname(path) == '.class'
      end

      def class_file_format(path)
        bits = File.open(path).read.unpack('H*')[0]
        @logger.debug { "Scanning #{path}:  #{bits[0, 8]}/#{bits[14, 2]}" }

        Integer(bits[14, 2]) if magic_number?(bits)
      end

      def compiled_version(root)
        @logger.debug { 'Detecting compiled version' }

        versions = find(root.to_path).map do |child|
          next if File.directory?(child) || !class?(child)
          class_file_format child
        end

        version versions.max_by(&:to_i)
      end

      def detect_compiled?(configuration)
        configuration[KEY_DETECT_COMPILED_VERSION] == 'enabled'
      end

      def killjava
        @droplet.sandbox + 'bin/killjava.sh'
      end

      def magic_number?(bits)
        bits[0, 8] == CAFEBABE
      end

      def memory(version)
        sizes      = @configuration[KEY_MEMORY_SIZES] ? @configuration[KEY_MEMORY_SIZES].clone : {}
        heuristics = @configuration[KEY_MEMORY_HEURISTICS] ? @configuration[KEY_MEMORY_HEURISTICS].clone : {}

        if version < VERSION_8
          heuristics.delete 'metaspace'
          sizes.delete 'metaspace'
        else
          heuristics.delete 'permgen'
          sizes.delete 'permgen'
        end

        OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
      end

      def version(format)
        if format == 32
          VERSION_6
        elsif format == 33
          VERSION_7
        else
          VERSION_8
        end
      end

    end

  end
end
