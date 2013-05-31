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

require 'java_buildpack/jre_properties'

module JavaBuildpack

  # Encapsulates the detection functionality in the Java buildpack
  class Detect

    # Creates a new instance, passing in the application directory used during detection
    #
    # @param [String] app_dir The application directory used during detection
    def initialize(app_dir)
      @jre_properties = JreProperties.new(app_dir)
    end

    # The execution entry point for detection.  This method is responsible for identifying all of the components that are
    # that which to participate in the buildpack and returning their names.
    #
    # @return [Array<String>] the names of components that wish to participate in the buildpack
    def run
      "java-#{@jre_properties.vendor}-#{@jre_properties.version}"
    end

  end
end
