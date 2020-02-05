# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/framework'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch JProfiler profiler support.
    class JprofilerProfiler < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'JProfiler Profiler'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        properties = { 'port' => port }
        properties['nowait'] = nil if nowait

        @droplet
          .java_opts
          .add_agentpath_with_props(file_name, properties)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['enabled']
      end

      private

      def file_name
        @droplet.sandbox + 'bin/linux-x64/libjprofilerti.so'
      end

      def nowait
        v = @configuration['nowait']
        v.nil? ? true : v
      end

      def port
        @configuration['port'] || 8_849
      end

    end

  end
end
