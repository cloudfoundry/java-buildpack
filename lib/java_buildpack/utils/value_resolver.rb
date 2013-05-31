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

require 'java_buildpack/utils/properties'

module JavaBuildpack

  # A resolver that selects values from environment variables and properties files
  class ValueResolver

    # Create a new instance, specifying the directory to recursively scan for a file called +system.properties+
    #
    # @param [String] root_dir the root directory to scan recursively for a called +system.properties+
    # @raise if more than one file called +system.properties+ is found under the +root_dir+
    def initialize(root_dir)
      raise "Invalid root directory '#{root_dir}'" if root_dir.nil? || root_dir.empty?
      @system_properties = ValueResolver.system_properties root_dir
    end

    # Resolves a value by inspecting an environment variable and a system property
    #
    # @param [String] env_var the name of the environment variable to inspect
    # @param [String] prop_key the key of the property to inspect
    # @return [String, nil] a resolved value. Follows the following algorithm
    #                       1. If environment variable is set, the value of the environment variable
    #                       2. If a +system.properties+ file is found and the property is set, the value of the property
    #                       3. +nil+
    def resolve(env_var, prop_key)
      value = ENV[env_var]

      if value.nil? && !@system_properties.nil?
        value = @system_properties[prop_key]
      end

      value
    end

    private

    SYSTEM_PROPERTIES = 'system.properties'

    def self.system_properties(root_dir)
      candidates = Dir["#{root_dir}/**/#{SYSTEM_PROPERTIES}"]

      if candidates.length > 1
        raise "More than one system.properties file found: #{candidates}"
      end

      if candidates[0]
        Properties.new(candidates[0])
      else
        nil
      end
    end
  end
end
