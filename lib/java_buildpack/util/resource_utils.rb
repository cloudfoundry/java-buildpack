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

require 'fileutils'
require 'java_buildpack/util'
require 'open3'

module JavaBuildpack::Util

  # Utilities for dealing with buildpack resources
  class ResourceUtils

    # Copies the contents of the given subdirectory of the buildpack resources directory to the given target directory.
    #
    # @param [String] subdirectory the subdirectory of the resources directory
    # @param [String] target the target directory
    def self.copy_resources(subdirectory, target)
      FileUtils.cp_r File.join(get_resources(subdirectory), '.'), target
    end

    # Returns the path of the given subdirectory of the buildpack resources directory.
    #
    # @param [String] subdirectory the subdirectory of the resources directory
    # @return [String] the path of the subdirectory
    def self.get_resources(subdirectory)
      File.join(File.expand_path(RESOURCES, File.dirname(__FILE__)), subdirectory)
    end

    private

    RESOURCES = File.join('..', '..', '..', 'resources').freeze

    private_class_method :new
  end

end
