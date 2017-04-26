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

require 'java_buildpack/component'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Component

    # An abstraction encapsulating the Environment Variables of an application.
    #
    # A new instance of this type should be created once for the application.
    class EnvironmentVariables < Array
      include JavaBuildpack::Util

      # Creates an instance of the Environment Variables abstraction.
      #
      # @param [Pathname] droplet_root the root directory of the droplet
      def initialize(droplet_root)
        @droplet_root = droplet_root
      end

      # Adds an environment variable. Prepends +$PWD+ to any variable values that are
      # paths (relative to the droplet root) to ensure that the path is always accurate.
      #
      # @param [String] key the variable name
      # @param [String] value the variable value
      # @return [EnvironmentVariables] +self+ for chaining
      def add_environment_variable(key, value)
        self << "#{key}=#{qualify_value(value)}"
      end

      # Returns the contents as an environment variable formatted as +<key>=<value>+
      #
      # @return [String] the contents as an environment variable
      def as_env_vars
        join(' ')
      end

      private

      def qualify_value(value)
        value.respond_to?(:relative_path_from) ? qualify_path(value) : value
      end

    end

  end
end
