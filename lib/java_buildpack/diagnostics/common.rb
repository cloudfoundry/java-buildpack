# Encoding: utf-8
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

require 'java_buildpack/diagnostics'

# Common constants and methods for the Diagnostics module.
module JavaBuildpack::Diagnostics

  # Returns the path of the buildpack diagnostics directory.
  #
  # @param [JavaBuildpack::Application::Application] application the application
  # @return [Pathname] the path to the diagnostics directory
  def self.get_diagnostic_directory(application)
    application.component_directory 'buildpack-diagnostics'
  end

  # Returns the path of the buildpack log file.
  #
  # @param [JavaBuildpack::Application::Application] application the application
  # @return [String] the path of the buildpack log file
  def self.get_buildpack_log(application)
    get_diagnostic_directory(application) + 'buildpack.log'
  end

end
