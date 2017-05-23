# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/filtering_pathname'
require 'pathname'

module JavaBuildpack
  module Component

    # An abstraction around the droplet that will be created and used at runtime.  This abstraction is intended to hide
    # the work done by components within their own sandboxes, while exposing changes made to the user's application.
    # Think of this as a mutable representation of a component's sandbox and the application that was uploaded.
    #
    # A new instance of this type should be created for each component.
    class Droplet

      # @!attribute [r] additional_libraries
      # @return [AdditionalLibraries] the shared +AdditionalLibraries+ instance for all components
      attr_reader :additional_libraries

      # @!attribute [r] component_id
      # @return [String] the id of component using this droplet
      attr_reader :component_id

      # @!attribute [r] environment_variables
      # @return [EnvironmentVariables] the shared +EnvironmentVariables+ instance for all components
      attr_reader :environment_variables

      # @!attribute [r] extension_directories
      # @return [ExtensionDirectories] the shared +ExtensionDirectories+ instance for all components
      attr_reader :extension_directories

      # @!attribute [r] java_home
      # @return [ImmutableJavaHome, MutableJavaHome] the shared +JavaHome+ instance for all components.  If the
      #                                              component using this instance is a jre, then this will be an
      #                                              instance of +MutableJavaHome+.  Otherwise it will be an instance of
      #                                              +ImmutableJavaHome+.
      attr_reader :java_home

      # @!attribute [r] java_opts
      # @return [JavaOpts] the shared +JavaOpts+ instance for all components
      attr_reader :java_opts

      # @!attribute [r] root
      # @return [JavaBuildpack::Util::FilteringPathname] the root of the droplet's fileystem filtered so that it
      #                                                  excludes files in the sandboxes of other components
      attr_reader :root

      # @!attribute [r] sandbox
      # @return [Pathname] the root of the component's sandbox
      attr_reader :sandbox

      # @!attribute [r] security_providers
      # @return [SecurityProviders] the shared +SecurityProviders+ instance for all components
      attr_reader :security_providers

      # Creates a new instance of the droplet abstraction
      #
      # @param [AdditionalLibraries] additional_libraries     the shared +AdditionalLibraries+ instance for all
      #                                                       components
      # @param [String] component_id                          the id of the component that will use this +Droplet+
      # @param [EnvironmentVariables] env_vars                the shared +EnvironmentVariables+ instance for all
      #                                                       components
      # @param [ExtensionDirectories] extension_directories   the shared +ExtensionDirectories+ instance for all
      #                                                       components
      # @param [ImmutableJavaHome, MutableJavaHome] java_home the shared +JavaHome+ instance for all components.  If the
      #                                                       component using this instance is a jre, then this should
      #                                                       be an instance of +MutableJavaHome+.  Otherwise it should
      #                                                       be an instance of +ImmutableJavaHome+.
      # @param [JavaOpts] java_opts                           the shared +JavaOpts+ instance for all components
      # @param [Pathname] root                                the root of the droplet
      # @param [SecurityProviders] security_providers         the shared +SecurityProviders+ instance for all components
      def initialize(additional_libraries, component_id, env_vars, extension_directories, java_home, java_opts, root,
                     security_providers)

        @additional_libraries  = additional_libraries
        @component_id          = component_id
        @environment_variables = env_vars
        @extension_directories = extension_directories
        @java_home             = java_home
        @java_opts             = java_opts
        @logger                = JavaBuildpack::Logging::LoggerFactory.instance.get_logger Droplet

        buildpack_root = root + '.java-buildpack'
        sandbox_root   = buildpack_root + component_id

        @sandbox            = JavaBuildpack::Util::FilteringPathname.new(sandbox_root,
                                                                         ->(path) { in?(path, sandbox_root) }, true)
        @root               = JavaBuildpack::Util::FilteringPathname.new(
          root,
          ->(path) { !in?(path, buildpack_root) || in?(path, @sandbox) },
          true
        )
        @security_providers = security_providers
      end

      # Copy resources from a components resources directory to a directory
      #
      # @param [Pathname] target_directory the directory to copy to.  Defaults to the component's +sandbox+.
      # @return [Void]
      def copy_resources(target_directory = @sandbox)
        resources = RESOURCES_DIRECTORY + @component_id

        if resources.exist?
          FileUtils.mkdir_p target_directory
          FileUtils.cp_r("#{resources}/.", target_directory)
          @logger.debug { "Resources #{resources} found" }
        else
          @logger.debug { "No resources #{resources} found" }
        end
      end

      private

      RESOURCES_DIRECTORY = Pathname.new(File.expand_path('../../../../resources', __FILE__)).freeze

      private_constant :RESOURCES_DIRECTORY

      def in?(path, root)
        path.ascend do |parent|
          return true if parent == root
        end
        false
      end

    end

  end
end
