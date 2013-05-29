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

  # A class encapsulating the JRE properties specified by the user.
  class JreProperties

    DEFAULT_VENDOR = 'openjdk'

    # @!attribute [r] vendor
    #   @return [String] the JRE vendor requested by the user
    # @!attribute [r] version
    #   @return [String] the JRE version requested by the user
    attr_reader :vendor, :version

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize(app_dir)
      properties = system_properties(app_dir)

      @vendor = configured_vendor properties
      @vendor = DEFAULT_VENDOR if @vendor.nil?

      @version = configured_version properties
    end

    private

    SYSTEM_PROPERTIES = 'system.properties'

    ENV_VAR_VENDOR = 'JAVA_RUNTIME_VENDOR'

    PROP_KEY_VENDOR = 'java.runtime.vendor'

    ENV_VAR_VERSION = 'JAVA_RUNTIME_VERSION'

    PROP_KEY_VERSION = 'java.runtime.version'

    def system_properties(app_dir)
      candidates = Dir["#{app_dir}/**/#{SYSTEM_PROPERTIES}"]

      if candidates.length > 1
        raise "More than one system.properties file found: #{candidates}"
      end

      if candidates[0]
        Properties.new(candidates[0])
      else
        nil
      end
    end

    def configured_vendor(properties)
      resolve ENV_VAR_VENDOR, PROP_KEY_VENDOR, properties
    end

    def configured_version(properties)
      resolve ENV_VAR_VERSION, PROP_KEY_VERSION, properties
    end

    def resolve(env_var, prop_key, properties, default = nil)
      value = ENV[env_var]

      if value.nil? && !properties.nil?
        value = properties[prop_key]
      end

      value
    end
  end
end
