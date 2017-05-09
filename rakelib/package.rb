# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

require 'java_buildpack/buildpack_version'

module Package

  def self.offline
    '-offline' if BUILDPACK_VERSION.offline
  end

  def self.version
    BUILDPACK_VERSION.version || 'unknown'
  end

  ARCHITECTURES = %w[x86_64].freeze

  BUILD_DIR = 'build'.freeze

  BUILDPACK_VERSION = JavaBuildpack::BuildpackVersion.new(false).freeze

  PLATFORMS = %w[trusty].freeze

  STAGING_DIR = "#{BUILD_DIR}/staging".freeze

  PACKAGE_NAME = "#{BUILD_DIR}/java-buildpack#{offline}-#{version}.zip".freeze

end
