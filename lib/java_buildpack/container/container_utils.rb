# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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
      value.nil? || value.empty? ? '' : " #{value}"
    end

  end

end
