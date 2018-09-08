# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2018 the original author or authors.
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
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting a JRE.
    class OpenJdkOpenJ9Initializer < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger OpenJdkOpenJ9Initializer

        @application    = context[:application]
        @component_name = context[:component_name]
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @droplet.java_home.root = @droplet.sandbox + 'jre/'
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version, @uri = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                             @configuration)
        @droplet.java_home.version = @version
        super
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources

        # stripping top level from tar doesn't seem to be enough
        # need to strip one more level
        orig_dir = Dir.entries(@droplet.sandbox).select { |f| f.start_with? 'jdk' }.first
        File.rename(File.join(@droplet.sandbox, orig_dir), @droplet.java_home.root) unless orig_dir.nil?
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
          .add_preformatted_options('-Xtune:virtualized')
          .add_preformatted_options('-Xshareclasses:none')
      end

    end

  end
end
