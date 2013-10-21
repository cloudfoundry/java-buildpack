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

require 'java_buildpack/container'
require 'pathname'

module JavaBuildpack::Container

  # Utilities common to container components
  class ContainerUtils

    # Converts an +Array+ of Java options to a +String+ suitable for use on a BASH command line
    #
    # @param [Array<String>] java_opts the array of Java options
    # @return [String] the options formatted as a string suitable for use on a BASH command line
    def self.to_java_opts_s(java_opts)
      java_opts.compact.sort.join(' ')
    end

    # Evaluates a value and if it is not +nil+ or empty, prepends it with a space.  This can be used to create BASH
    # command lines that do not have ugly extra spacing.
    #
    # @param [String, nil] value the value to evalutate for extra spacing
    # @return [String] an empty string if +value+ is +nil+ or empty, otherwise the value prepended with a space
    def self.space(value)
      value = value.to_s if value.respond_to?(:to_s)
      value.nil? || value.empty? ? '' : " #{value}"
    end

    # Returns an +Array+ containing the relative paths of the JARs located in the additional libraries directory.  The
    # paths of these JARs are relative to the +root_dir+.
    #
    # @param [String] root_dir the directory relative to which the resultant are calculated
    # @param [String] lib_directory the directory that additional libraries are placed in
    # @return [Array<String>] the relative paths of the JARs located in the additional libraries directory
    def self.libs(root_dir, lib_directory)
      libs = []

      if lib_directory
        root_directory = Pathname.new(root_dir)

        libs = Pathname.new(lib_directory).children
        .select { |file| file.extname == '.jar' }
        .map { |file| file.relative_path_from(root_directory) }
        .sort
      end

      libs
    end

  end

end
