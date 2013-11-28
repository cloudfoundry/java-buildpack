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
require 'java_buildpack/application'
require 'pathname'

module JavaBuildpack::Application

  # An abstraction encapsulating the additional libraries attached to an application
  class AdditionalLibraries < Pathname

    # Creates an instance of the +JAVA_HOME+ abstraction.
    #
    # @param [Pathname] root the root directory of the application
    def initialize(root)
      @root = root
      @additional_paths = []
      @additional_libraries = @root + LIB_DIRECTORY
      FileUtils.mkdir_p @additional_libraries

      super(@additional_libraries)
    end

    # Add an additional path to the additional libraries collection
    #
    # @param [Pathname] path the path to add
    # @return [AdditionalLibraries] self to facilitate chaining
    def add(path)
      @additional_paths << path
      self
    end

    # Returns the contents of the collection as a classpath formatted as +-cp <value1>:<value2>+
    #
    # @return [String] the contents of the collection as a classpath
    def as_classpath
      qualified_paths = paths.map { |path| qualify_path path }

      "-cp #{qualified_paths.join ':'}"
    end

    # Symlink the contents of the collection to a destination directory.
    #
    # @param [Pathname] destination the destination to link to
    def link_to(destination)
      FileUtils.mkdir_p destination
      paths.each { |path| (destination + path.basename).make_symlink(path.relative_path_from(destination)) }
    end

    # The paths to the additional libraries
    #
    # @return [Array<Pathname>] the paths to the additional libraries
    def paths
      paths = []
      paths.concat @additional_paths
      paths.concat @additional_libraries.children
                   .select { |child| child.extname == '.jar' }

      paths.sort
    end

    private

    LIB_DIRECTORY = '.additional-libraries'.freeze

    def qualify_path(path)
      "$PWD/#{path.relative_path_from @root}"
    end

  end

end
