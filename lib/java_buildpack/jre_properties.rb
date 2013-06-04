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


require 'java_buildpack/utils/value_resolver'
require 'java_buildpack/vendor_resolver'
require 'java_buildpack/version_resolver'
require 'open-uri'
require 'yaml'


module JavaBuildpack

  # A class encapsulating properties of the JRE specified by the user.
  class JreProperties

    # @!attribute [r] id
    #   @return [String] a unique identifier for the resolved JRE based on user input
    # @!attribute [r] vendor
    #   @return [String] the resolved JRE vendor based on user input
    # @!attribute [r] version
    #   @return [String] the resolved JRE version based on user input
    # @!attribute [r] uri
    #   @return [String] the resolved JRE URI based on user input
    attr_reader :id, :vendor, :version, :uri

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize(app_dir)
      value_resolver = ValueResolver.new(app_dir)
      candidate_vendor = value_resolver.resolve(ENV_VAR_VENDOR, SYS_PROP_VENDOR)
      candidate_version = value_resolver.resolve(ENV_VAR_VERSION, SYS_PROP_VERSION)

      vendors = load_vendors
      @vendor = VendorResolver.resolve(candidate_vendor, vendors.keys)
      vendor_details = vendors[@vendor]

      repository_root = find_repository_root vendor_details
      default_version = find_default_version vendor_details
      versions = load_versions(repository_root)

      @version = VersionResolver.resolve(candidate_version, default_version, versions.keys)

      @uri = "#{repository_root}/#{versions[@version]}"
      @id = "jre-#{@vendor}-#{@version}"
    end

    private

    ENV_VAR_VENDOR = 'JAVA_RUNTIME_VENDOR'

    ENV_VAR_VERSION = 'JAVA_RUNTIME_VERSION'

    INDEX_PATH = '/index.yml'

    JRES_YAML_FILE = '../../config/jres.yml'

    KEY_DEFAULT_VERSION = 'default_version'

    KEY_REPOSITORY_ROOT = 'repository_root'

    SYS_PROP_VENDOR = 'java.runtime.vendor'

    SYS_PROP_VERSION = 'java.runtime.version'

    def find_default_version(vendor_details)
      if vendor_details.is_a?(Hash) && vendor_details.has_key?(KEY_DEFAULT_VERSION)
        default_version = vendor_details[KEY_DEFAULT_VERSION]
      else
        default_version = nil
      end
    end

    def find_repository_root(vendor_details)
      if vendor_details.is_a? String
        repository_root = vendor_details
      elsif vendor_details.is_a?(Hash) && vendor_details.has_key?(KEY_REPOSITORY_ROOT)
        repository_root = vendor_details[KEY_REPOSITORY_ROOT]
      else
        raise "Vendor details must be either a String or a Hash with a key of '#{KEY_REPOSITORY_ROOT}' and a value that is a String that points to the root of a JRE repository."
      end

      repository_root
    end

    def load_versions(repository_root)
      YAML.parse(open "#{repository_root}#{INDEX_PATH}").to_ruby
    end

    def load_vendors
      YAML.load_file(File.expand_path JRES_YAML_FILE, File.dirname(__FILE__))
    end

  end
end
