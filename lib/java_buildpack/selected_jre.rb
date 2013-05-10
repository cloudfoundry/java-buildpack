# Cloud Foundry Java Buildpack Utilities
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

    # The property key for specifying the vendor
    KEY_VENDOR = 'java.runtime.vendor'

    # The default JRE version
    DEFAULT_VERSION = '7'

    # The property key for specifying the version
    KEY_VERSION = 'java.runtime.version'

    # The collection of legal JREs
    JRES = {
        openjdk: {
            J6: '',
            J7: '',
            J8: 'http://download.java.net/jdk8/archive/b88/binaries/jre-8-ea-bin-b88-linux-x64-02_may_2013.tar.gz'
        },
        oracle: {
            J6: '',
            J7: 'http://javadl.sun.com/webapps/download/AutoDL?BundleId=76853',
            J8: ''
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
      @version = configured_version properties
      @id = "java-#{@vendor}-#{@version}"
      @uri = JRES[@vendor.to_sym]["J#{@version}".to_sym]
    end

    private

    SYSTEM_PROPERTIES = 'system.properties'

    def normalize_version(raw_version)
      /(1.)?([\d])/.match(raw_version)[2]
    end

    def system_properties(app_dir)
      candidates = Dir["**/#{SYSTEM_PROPERTIES}"]

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
      vendor = nil

      unless properties.nil?
        vendor = properties[KEY_VENDOR]
      end

      vendor
    end

    def configured_version(properties)
      raw_version = nil

      unless properties.nil?
        raw_version = properties[KEY_VERSION]
      end

      normalize_version raw_version
    end
  end
end
