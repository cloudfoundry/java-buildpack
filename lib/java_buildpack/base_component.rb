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
require 'java_buildpack'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/library_utils'
require 'java_buildpack/util/shell'

module JavaBuildpack

  # A convenience base class for all components in the buildpack.  This base class ensures that the contents of the
  # +context+ are assigned to instance variables matching their keys.  It also ensures that all contract methods are
  # implemented.
  class BaseComponent
    include JavaBuildpack::Util::Shell

    # @!attribute [r] size
    #   @return [String] the name of this component
    attr_reader :component_name

    # Creates an instance.  The contents of +context+ are assigned to instance variables matching their keys.
    # +component_name+ and +context+ are exposed via +@component_name+ and +@context+ respectively for any component
    # that wishes to use them.  An additional +@parsable_component_name+ is exposed that is a lowercased and space-
    # removed version of +component_name+.
    #
    # @param [String] component_name The name of the component
    # @param [Hash] context A shared context provided to all components
    def initialize(component_name, context)
      @component_name = component_name
      @parsable_component_name = component_name.gsub(/ /, '-').downcase

      @context = context
      @context.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    # If the component should be used when staging an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +openjdk=1.7.0_40+).  Otherwise, +nil+.
    def detect
      fail "Method 'detect' must be defined"
    end

    # Modifies the application's file system.  The component is expected to transform the application's file system in
    # whatever way is necessary (e.g. downloading files or creating symbolic links) to support the function of the
    # component.  Status output written to +STDOUT+ is expected as part of this invocation.
    #
    # @return [void]
    def compile
      fail "Method 'compile' must be defined"
    end

    # Modifies the application's runtime configuration. The component is expected to transform members of the +context+
    # (e.g. +@java_home+, +@java_opts+, etc.) in whatever way is necessary to support the function of the component.
    #
    # Container components are also expected to create the command required to run the application.  These components
    # are expected to read the +context+ values and take them into account when creating the command.
    #
    # @return [void, String] components other than containers are not expected to return any value.  Container
    #                        components are expected to return the command required to run the application.
    def release
      fail "Method 'release' must be defined"
    end

    protected

    # Downloads an item with the given name and version from the given URI, then yields the resultant file to the given
    # block.
    #
    # @param [JavaBuildpack::Util::TokenizedVersion] version
    # @param [String] uri
    # @param [String] description an optional description for the download.  Defaults to +@component_name+.
    # @return [void]
    def download(version, uri, description = @component_name, &block)
      download_start_time = Time.now
      print "-----> Downloading #{description} #{version} from #{uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(uri) do |file| # TODO: Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        yield file
      end
    end

    # Downloads a given JAR and copies it to a given destination.
    #
    # @param [JavaBuildpack::Util::TokenizedVersion] version the version of the item
    # @param [String] uri the URI of the item
    # @param [String] jar_name the filename of the item
    # @param [String] target_directory the path of the directory into which to download the item. Defaults to
    #                                  +@lib_directory+
    # @param [String] description an optional description for the download.  Defaults to +@component_name+.
    def download_jar(version, uri, jar_name, target_directory = @lib_directory, description = @component_name)
      download(version, uri, description) { |file| FileUtils.cp file.path, File.join(target_directory, jar_name) }
    end

    # Returns the additional libraries.
    #
    # @param [Array<String>] the paths of JARs in the additional libraries directory
    def additional_libraries
      JavaBuildpack::Util::LibraryUtils.lib_jars @lib_directory
    end

  end

end
