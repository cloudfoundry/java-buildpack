# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/component'
require 'java_buildpack/component/base_component'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/dash_case'
require 'tmpdir'

module JavaBuildpack
  module Component

    # A convenience base class for all components that have a versioned dependency.  In addition to the functionality
    # inherited from +BaseComponent+ this class also ensures that managed dependencies are handled in a uniform manner.
    class VersionedDependencyComponent < BaseComponent

      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
      # instance variables are exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      # @param [Block, nil] version_validator an optional version validation block
      def initialize(context, &version_validator)
        super(context)

        if supports?
          @version, @uri = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, @configuration,
                                                                               &version_validator)
        else
          @version = nil
          @uri     = nil
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version ? id(@version) : nil
      end

      protected

      # Whether or not this component supports this application
      #
      # @return [Boolean] whether or not this component supports this application
      def supports?
        raise "Method 'supports?' must be defined"
      end

      # Downloads a given JAR file and stores it.
      #
      # @param [String] jar_name the name to save the jar as
      # @param [Pathname] target_directory the directory to store the JAR file in.  Defaults to the component's sandbox.
      # @param [String] name an optional name for the download.  Defaults to +@component_name+.
      # @return [Void]
      def download_jar(jar_name = self.jar_name, target_directory = @droplet.sandbox, name = @component_name)
        super(@version, @uri, jar_name, target_directory, name)
      end

      # Downloads a given TAR file and expands it.
      #
      # @param [Boolean] strip_top_level whether to strip the top-level directory when expanding. Defaults to +true+.
      # @param [Pathname] target_directory the directory to expand the TAR file to.  Defaults to the component's
      #                                    sandbox.
      # @param [String] name an optional name for the download and expansion.  Defaults to +@component_name+.
      # @return [Void]
      def download_tar(strip_top_level = true, target_directory = @droplet.sandbox, name = @component_name)
        super(@version, @uri, strip_top_level, target_directory, name)
      end

      # Downloads a given ZIP file and expands it.
      #
      # @param [Boolean] strip_top_level whether to strip the top-level directory when expanding. Defaults to +true+.
      # @param [Pathname] target_directory the directory to expand the ZIP file to.  Defaults to the component's
      #                                    sandbox.
      # @param [String] name an optional name for the download.  Defaults to +@component_name+.
      # @return [Void]
      def download_zip(strip_top_level = true, target_directory = @droplet.sandbox, name = @component_name)
        super(@version, @uri, strip_top_level, target_directory, name)
      end

      # A generated JAR name for the component.  Meets the format +<component-id>-<version>.jar+
      #
      # @return [String] a generated JAR name for the component
      def jar_name
        "#{@droplet.component_id}-#{@version}.jar"
      end

      private

      def id(version)
        "#{self.class.to_s.dash_case}=#{version}"
      end

    end

  end
end
