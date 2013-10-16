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
require 'java_buildpack/base_component'
require 'java_buildpack/repository/configured_item'

module JavaBuildpack

  # A convenience base class for all components that have a versioned dependency.  In addition to the functionality
  # inherited from +BaseComponent+ this class also ensures that managed dependencies are handled in a uniform manner.
  class VersionedDependencyComponent < BaseComponent

    # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
    # instance variables are exposed.
    def initialize(component_name, context, &version_validator)
      super(component_name, context)
      @version, @uri = supports? ? JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, @configuration, &version_validator) : [nil, nil]
    end

    # If the component should be used when stagingin an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +openjdk-1.7.0_40+).  Otherwise, +nil+.
    def detect
      @version ? id(@version) : nil
    end

    protected

    # The unique indentifier of the component, incorporating the version of the dependency (e.g. +openjdk-1.7.0_40+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def id(version)
      fail "Method 'id(version)' must be defined"
    end

    # Whether or not this component supports this application
    #
    # @return [Boolean] whether or not this component supports this application
    def supports?
      fail "Method 'supports?' must be defined"
    end

    alias_method :super_download, :download

    # Downloads the versioned dependency, then yields the resultant file to the given block.
    #
    # @return [void]
    def download(description = @component_name, &block)
      super_download @version, @uri, description, &block
    end

    # Downloads a given JAR and copies it to a given destination.
    #
    # @param [String] jar_name the filename of the item
    # @param [String] target_directory the path of the directory into which to download the item. Defaults to
    #                                  +@lib_directory+
    # @param [String] description an optional description for the download.  Defaults to +@component_name+.
    def download_jar(jar_name, target_directory = @lib_directory, description = @component_name)
      download(description) { |file| shell "cp #{file.path} #{File.join(target_directory, jar_name)}" }
    end

  end

end
