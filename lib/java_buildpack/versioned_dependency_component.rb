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
require 'java_buildpack/base_component'
require 'java_buildpack/repository/configured_item'
require 'tmpdir'

module JavaBuildpack

  # A convenience base class for all components that have a versioned dependency.  In addition to the functionality
  # inherited from +BaseComponent+ this class also ensures that managed dependencies are handled in a uniform manner.
  class VersionedDependencyComponent < BaseComponent

    # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
    # instance variables are exposed.
    def initialize(component_name, context, &version_validator)
      super(component_name, context)

      if supports?
        @version, @uri = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name, @configuration,
                                                                             &version_validator)
      else
        @version = nil
        @uri = nil
      end
    end

    # If the component should be used when stagingin an application
    #
    # @return [Array<String>, String, nil] If the component should be used when staging the application, a +String+ or
    #                                      an +Array<String>+ that uniquely identifies the component (e.g.
    #                                      +openjdk=1.7.0_40+).  Otherwise, +nil+.
    def detect
      @version ? id(@version) : nil
    end

    protected

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
      download(description) { |file| FileUtils.cp file.path, File.join(target_directory, jar_name) }
    end

    # Downloads a given ZIP file and expands it to a given destination.
    #
    # @param [String] target_directory the path of the directory into which to expand the item
    # @param [Boolean] strip_top_level_directory Whether to strip the top-level directory when expanding. Defaults to +true+.
    # @param [String] description an optional description for the download and expansion.  Defaults to +@component_name+.
    def download_zip(target_directory, strip_top_level_directory = true, description = @component_name)
      download(description) do |file|
        expand_start_time = Time.now
        print "       Expanding #{description} to #{target_directory} "

        FileUtils.rm_rf target_directory
        FileUtils.mkdir_p File.dirname(target_directory)

        if strip_top_level_directory
          Dir.mktmpdir do |root|
            shell "unzip -qq #{file.path} -d #{root} 2>&1"
            FileUtils.mv Dir[root + '/*'][0], target_directory
          end
        else
          shell "unzip -qq #{file.path} -d #{target_directory} 2>&1"
        end

        puts "(#{(Time.now - expand_start_time).duration})"
      end
    end

    private

    def id(version)
      "#{@parsable_component_name}=#{version}"
    end

  end

end
