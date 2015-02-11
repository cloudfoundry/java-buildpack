# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                                         @configuration)
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

      private_constant :KEY_MEMORY_HEURISTICS, :KEY_MEMORY_SIZES

      def killjava
        @droplet.sandbox + 'bin/killjava.sh'
      end

      def memory
        sizes      = @configuration[KEY_MEMORY_SIZES] || {}
        heuristics = @configuration[KEY_MEMORY_HEURISTICS] || {}
        OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
      end

    end

  end
end
