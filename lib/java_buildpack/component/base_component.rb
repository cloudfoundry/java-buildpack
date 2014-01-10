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
require 'java_buildpack/component'
require 'java_buildpack/util/cache/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/shell'
require 'java_buildpack/util/space_case'

module JavaBuildpack::Component

  # A convenience base class for all components in the buildpack.  This base class ensures that the contents of the
  # +context+ are assigned to instance variables matching their keys.  It also ensures that all contract methods are
  # implemented.
  class BaseComponent
    include JavaBuildpack::Util::Shell

    # Creates an instance.  The contents of +context+ are assigned to the instance variables matching their keys.
    #
    # @param [Hash] context a collection of utilities used by components
    # @option context [JavaBuildpack::Component::Application] :application the application
    # @option context [Hash] :configuration the component's configuration
    # @option context [JavaBuildpack::Component::Droplet] :droplet the droplet
    def initialize(context)
      @application    = context[:application]
      @component_name = self.class.to_s.space_case
      @configuration  = context[:configuration]
      @droplet        = context[:droplet]
    end

    # If the component should be used when staging an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +open_jdk=1.7.0_40+).  Otherwise, +nil+.
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
    # @param [String] name an optional name for the download.  Defaults to +@component_name+.
    # @return [void]
    def download(version, uri, name = @component_name, &block)
      download_start_time = Time.now
      print "-----> Downloading #{name} #{version} from #{uri} "

      JavaBuildpack::Util::Cache::ApplicationCache.new.get(uri) do |file| # TODO: Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        yield file
      end
    end

    # Downloads a given JAR file and stores it.
    #
    # @param [String] version the version of the download
    # @param [String] uri the uri of the download
    # @param [String] jar_name the name to save the jar as
    # @param [Pathname] target_directory the directory to store the JAR file in.  Defaults to the component's sandbox.
    # @param [String] name an optional name for the download.  Defaults to +@component_name+.
    def download_jar(version, uri, jar_name, target_directory = @droplet.sandbox, name = @component_name)
      download(version, uri, name) do |file|
        FileUtils.mkdir_p target_directory
        FileUtils.cp_r(file.path, target_directory + jar_name)
      end
    end

    # Downloads a given TAR file and expands it.
    #
    # @param [String] version the version of the download
    # @param [String] uri the uri of the download
    # @param [Pathname] target_directory the directory to expand the TAR file to.  Defaults to the component's sandbox.
    # @param [String] name an optional name for the download and expansion.  Defaults to +@component_name+.
    def download_tar(version, uri, target_directory = @droplet.sandbox, name = @component_name)
      download(version, uri, name) do |file|
        with_timing "Expanding #{name} to #{target_directory.relative_path_from(@droplet.root)}" do
          FileUtils.mkdir_p target_directory
          shell "tar xzf #{file.path} -C #{target_directory} --strip 1 2>&1"
        end
      end
    end

    # Downloads a given ZIP file and expands it.
    #
    # @param [Boolean] strip_top_level whether to strip the top-level directory when expanding. Defaults to +true+.
    # @param [Pathname] target_directory the directory to expand the ZIP file to.  Defaults to the component's sandbox.
    # @param [String] name an optional name for the download.  Defaults to +@component_name+.
    def download_zip(version, uri, strip_top_level = true, target_directory = @droplet.sandbox, name = @component_name)
      download(version, uri, name) do |file|
        with_timing "Expanding #{name} to #{target_directory.relative_path_from(@droplet.root)}" do
          if strip_top_level
            Dir.mktmpdir do |root|
              shell "unzip -qq #{file.path} -d #{root} 2>&1"

              FileUtils.mkdir_p target_directory.parent
              FileUtils.mv Pathname.new(root).children.first, target_directory
            end
          else
            FileUtils.mkdir_p target_directory
            shell "unzip -qq #{file.path} -d #{target_directory} 2>&1"
          end
        end
      end
    end

    # Wrap the execution of a block with timing information
    #
    # @param [String] caption the caption to print when timing starts
    def with_timing(caption)
      start_time = Time.now
      print "       #{caption} "

      yield

      puts "(#{(Time.now - start_time).duration})"
    end

  end

end
