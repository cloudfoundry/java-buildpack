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

  # A class which maps the user's requested JRE vendor and version to a URI.
  class JreSelector

    # The collection of legal JREs
    JRES = {     #FIXME externalise this
      'openjdk' => {
        '8' => {
          :uri => 'http://download.java.net/jdk8/archive/b88/binaries/jre-8-ea-bin-b88-linux-x64-02_may_2013.tar.gz'
        }
      }
    }

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize()
    end

    # @param [Object] vendor
    # @param [Object] version
    def uri(vendor, version)
      normalized_version = normalize_version version

      raise "'#{vendor}' is not a valid Java runtime vendor" unless JRES.has_key?(vendor)
      raise "'#{version}' is not a valid Java runtime version" unless JRES[vendor].has_key?(normalized_version)

      JRES[vendor][normalized_version][:uri]
    end

    private

    def normalize_version(raw_version)
      /(1.)?([\d])/.match(raw_version)[2]
    end

  end
end
