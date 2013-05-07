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

# Encapsulates the release functionality in the Java buildpack
class JavaBuildpack::Release

  # Creates a new instance, passing in the application directory used during release
  #
  # @param [String] app_dir The application directory used during release
  def initialize(app_dir)

  end

  # The execution entry point for release.  This method is responsible for generating a payload describing the execution
  # command used to start the application.
  #
  # @return [String] the YAML formatted payload describing the execution command used to start the application
  def run
    {
        addons: [],
        config_vars: {},
        default_process_types: {
            web: ''
        }
    }.to_yaml
  end

end
