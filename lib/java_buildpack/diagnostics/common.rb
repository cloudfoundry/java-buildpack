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
  # The directory that diagnostics are written into
  DIAGNOSTICS_DIRECTORY = '.buildpack-diagnostics'.freeze

  # The name of the buildpack diagnostic log file.
  LOG_FILE_NAME = 'buildpack.log'.freeze

  # Returns the full path of the buildpack diagnostics directory.
  #
  # @param [String] app_dir the application root directory
  # @return [String] the full path of the buildpack diagnostics directory
  def self.get_diagnostic_directory(app_dir)
    File.join(app_dir, DIAGNOSTICS_DIRECTORY)
  end

  # Returns the full path of the buildpack log file.
  #
  # @param [String] app_dir the application root directory
  # @return [String] the full path of the buildpack log file
  def self.get_buildpack_log(app_dir)
    File.join(get_diagnostic_directory(app_dir), LOG_FILE_NAME)
  end

end
