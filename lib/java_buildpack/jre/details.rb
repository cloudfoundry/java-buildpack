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

require 'java_buildpack/jre'
require 'java_buildpack/jre/vendor_resolver'
require 'java_buildpack/jre/version_resolver'
require 'open-uri'
require 'yaml'

module JavaBuildpack::Jre

  # A class encapsulating details of the JRE specified by the user.  This class can be used to get the details about any
  # JRE that is described in
  # {config/jres.yml}[https://github.com/cloudfoundry/java-buildpack/tree/master/config/jres.yml].
  #
  # === Adding JRES
  # To allow users to choose a JRE from other vendors, these vendors must be specified in
  # {config/jres.yml}[https://github.com/cloudfoundry/java-buildpack/tree/master/config/jres.yml]. This YAML file is, in
  # the simplest case, a mapping from a vendor name to a +String+ repository root URI.
  #
  #   <vendor name>: <JRE repository root URI>
  #
  # When configured like this, if the user does not specify a version of the JRE to use, the latest possible version
  # will be selected.  If a particular JRE should use a default that is not the latest (e.g. using `1.7.0_21` instead of
  # `1.8.0_M7`), the default version can be specified by using a `Hash` instead of a `String` as the value.
  #
  #   <vendor name>:
  #     default_version: <default version pattern>
  #     repository_root: <JRE repository root URI>
  #
  # The JRE repository root must contain an +/index.yml+ file
  # ({example}[http://jres.gopivotal.com.s3.amazonaws.com/lucid/x86_64/openjdk/index.yml]).  This YAML file is formatted
  # with the following syntax.
  #
  #   <JRE version>: <path relative to JRE repository root>
  #
  # The JRES uploaded to the repository must be gzipped TAR files and have no top-level directory
  # ({example}[http://jres.gopivotal.com.s3.amazonaws.com/lucid/x86_64/openjdk/openjdk-1.8.0_M7.tar.gz]).
  #
  # An example filesystem might look like this.
  #
  #   /index.yml
  #   /openjdk-1.6.0_27.tar.gz
  #   /openjdk-1.7.0_21.tar.gz
  #   /openjdk-1.8.0_M7.tar.gz
  class Details

    # @!attribute [r] vendor
    #   @return [String] the resolved JRE vendor based on user input
    # @!attribute [r] version
    #   @return [String] the resolved JRE version based on user input
    # @!attribute [r] uri
    #   @return [String] the resolved JRE URI based on user input
    attr_reader :vendor, :version, :uri

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [JavaBuildpack::Util::SystemProperties] system_properties the properties provided by the user
    def initialize(system_properties = {})
      candidate_vendor = system_properties[SYS_PROP_VENDOR]
      candidate_version = system_properties[SYS_PROP_VERSION]

      vendors = load_vendors
      @vendor = VendorResolver.resolve(candidate_vendor, vendors.keys)
      vendor_details = vendors[@vendor]

      repository_root = find_repository_root vendor_details
      default_version = find_default_version vendor_details
      versions = load_versions(repository_root)

      @version = VersionResolver.resolve(candidate_version, default_version, versions.keys)

      @uri = "#{repository_root}/#{versions[@version]}"
    end

    private

    INDEX_PATH = '/index.yml'

    JRES_YAML_FILE = '../../../config/jres.yml'

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
