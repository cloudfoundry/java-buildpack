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

  # A class encapsulating the JRE properties specified by the user.
  class JreProperties

    # @!attribute [r] vendor
    #   @return [String] the resolved JRE vendor based on user input
    # @!attribute [r] version
    #   @return [String] the resolved JRE version based on user input
    # @!attribute [r] uri
    #   @return [String] the resolved JRE URI based on user input
    attr_reader :vendor, :version, :uri

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize(app_dir)
      value_resolver = ValueResolver.new(app_dir)

      candidate_vendor = value_resolver.resolve(ENV_VAR_VENDOR, SYS_PROP_VENDOR)
      candidate_version = value_resolver.resolve(ENV_VAR_VERSION, SYS_PROP_VERSION)

      jre_vendor_repositories = YAML.load_file JRES_YAML_FILE
      @vendor = VendorResolver.resolve(candidate_vendor, jre_vendor_repositories.keys)
      repository = jre_vendor_repositories[@vendor]
      index = YAML.parse(open "#{repository}#{INDEX_PATH}").to_ruby
      @version = VersionResolver.resolve(candidate_version, index.keys)
      @uri = "#{repository}/#{index[@version]}"
    end

    private

    ENV_VAR_VENDOR = 'JAVA_RUNTIME_VENDOR'

    ENV_VAR_VERSION = 'JAVA_RUNTIME_VERSION'

    INDEX_PATH = '/index.yml'

    JRES_YAML_FILE = 'config/jres.yml'

    SYS_PROP_VENDOR = 'java.runtime.vendor'

    SYS_PROP_VERSION = 'java.runtime.version'

  end
end
