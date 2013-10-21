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

require 'java_buildpack'
require 'pathname'

module JavaBuildpack

  # An abstraction around the user's application.  This is intended to hide the exact structure of the +app_dir+ from
  # components.  Instead, components should use this abstraction to examine the bits of the filesystem that are specific
  # to it, and the application itself.
  class Application

    # Creates an instance of the application abstraction.
    def initialize(app_dir)
      @root = Pathname.new(app_dir)

      @initial_contents = []
      @root.find { |pathname| @initial_contents << pathname }
    end

    # Returns a child with the specified relative path
    #
    # @param [String] relative_path the path to the child, relative to the application
    # @return [Pathname] the path to the child
    def child(relative_path)
      child = @root + relative_path
      child if @initial_contents.include?(child) || !child.exist?
    end

    # Returns the children of the application (files and subdirectories, not recursive) as an array of +Pathname+
    # objects.  Does not include any files created by other components.
    #
    # @return [Array<Pathname>] the children of the application
    # @see Pathname
    def children
      @root.children & @initial_contents
    end

    # Returns the path to a directory that can be used by the component.  The
    # return value of this method should be considered opaque and subject to
    # change.
    #
    # @param [String] identifier an identifier for the component
    # @return [Pathname] the path to the directory
    def component_directory(identifier)
      @root + ".#{identifier.downcase}"
    end

    # Returns a path relative to the application root
    #
    # @param [Pathname] other the other path
    # @return [Patname] the relative path
    def relative_path_to(other)
      other.relative_path_from(@root)
    end

  end

end
