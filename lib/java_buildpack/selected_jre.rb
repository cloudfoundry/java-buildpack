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

  # A class containing information about the JRE selected by the user.
  class SelectedJre

    # The default JRE vendor
    DEFAULT_VENDOR = 'oracle'

    # The environment variable for specifying the vendor
    ENV_VAR_VENDOR = 'JAVA_RUNTIME_VENDOR'

    # The property key for specifying the vendor
    PROP_KEY_VENDOR = 'java.runtime.vendor'

    # The default JRE version
    DEFAULT_VERSION = '7'

    # The environment variable for specifying the version
    ENV_VAR_VERSION = 'JAVA_RUNTIME_VERSION'

    # The property key for specifying the version
    PROP_KEY_VERSION = 'java.runtime.version'

    # The collection of legal JREs
    JRES = {
        'openjdk' => {
            '6' => '',
            '7' => '',
            '8' => 'http://download.java.net/jdk8/archive/b88/binaries/jre-8-ea-bin-b88-linux-x64-02_may_2013.tar.gz'
        },
        'oracle' => {
            '6' => '',
            '7' => 'http://javadl.sun.com/webapps/download/AutoDL?BundleId=76853',
            '8' => ''
        }
    }

    # @!attribute [r] id
    #   @return [String] a unique value indicating exactly which JRE is being used. The value is structured as
    #                    'java-<vendor>-<version>'
    # @!attribute [r] uri
    #   @return [String] the download URI for the JRE being used
    # @!attribute [r] vendor
    #   @return [String] the vendor for the JRE being used
    # @!attribute [r] version
    #   @return [String] the version for the JRE being used
    attr_reader :id, :uri, :vendor, :version

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize(app_dir)
      properties = system_properties(app_dir)

      @vendor = configured_vendor properties
      raise "'#{@vendor}' is not a valid Java runtime vendor" unless JRES.has_key?(@vendor)

      @version = configured_version properties
      raise "'#{@version}' is not a valid Java runtime version" unless JRES[@vendor].has_key?(@version)

      @id = "java-#{@vendor}-#{@version}"
      @uri = JRES[@vendor][@version]
    end

    private

    SYSTEM_PROPERTIES = 'system.properties'

    def normalize_version(raw_version)
      /(1.)?([\d])/.match(raw_version)[2]
    end

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
      raw_version = resolve ENV_VAR_VERSION, PROP_KEY_VERSION, properties
      normalize_version raw_version
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
