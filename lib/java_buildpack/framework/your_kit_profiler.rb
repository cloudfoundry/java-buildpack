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

    # Encapsulates the functionality for enabling zero-touch YourKit profiler support.
    class YourKitProfiler < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'YourKit Profiler'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri, @component_name) do |file|
          FileUtils.mkdir_p @droplet.sandbox
          FileUtils.cp_r(file.path, file_name)
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_agentpath_with_props(file_name,
                                    'dir' => snapshots, 'logdir' => logs,
                                    'port' => port, 'sessionname' => session_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['enabled']
      end

      private

      def file_name
        @droplet.sandbox + "#{@droplet.component_id}-#{@version}"
      end

      def logs
        qualify_path(@droplet.sandbox + 'logs', @droplet.root)
      end

      def port
        @configuration['port'] || 10_001
      end

      def session_name
        @configuration['default_session_name'] || @application.details['application_name']
      end

      def snapshots
        qualify_path(@droplet.sandbox + 'snapshots', @droplet.root)
      end

    end

  end
end
