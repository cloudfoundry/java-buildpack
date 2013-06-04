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

require 'java_buildpack'
require 'java_buildpack/util/properties'

module JavaBuildpack

  # A class representing the system properties passed in by the user
  class SystemProperties < JavaBuildpack::Util::Properties

    # Create a new instance, populating it with values from a +system.properties+ file if it exists.
    #
    # @param [String] app_dir the application directory to inspect for a +system.properties+ file
    # @raise if more than one +system.properties+ file is found
    def initialize(app_dir)
      candidates = Dir["#{app_dir}/**/#{SYSTEM_PROPERTIES}"]

      if candidates.length > 1
        raise "More than one system.properties file found: #{candidates}"
      end

      super(candidates[0])
    end

    private

    SYSTEM_PROPERTIES = 'system.properties'.freeze

  end

end
