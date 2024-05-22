# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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

  def packaging
    @pkgcfg = configuration('packaging') if @pkgcfg.nil?
    @pkgcfg
  end

  def configuration(id)
    JavaBuildpack::Util::ConfigurationUtils.load(id, false, false)
  end

  def configurations(component_id, configuration, sub_component_id = nil)
    configurations = []

    if repository_configuration?(configuration)
      configuration['component_id'] = component_id
      configuration['sub_component_id'] = sub_component_id if sub_component_id

      Utils::VersionUtils.java_version_lines(configuration, configurations) \
          if Utils::VersionUtils.openjdk_jre? configuration

      Utils::VersionUtils.tomcat_version_lines(configuration, configurations) \
          if Utils::VersionUtils.tomcat? configuration

      configurations << configuration
    else
      configuration.each { |k, v| configurations << configurations(component_id, v, k) if v.is_a? Hash }
    end

    configurations
  end

  def index_configuration(configuration)
    [configuration['repository_root']]
      .map { |r| { uri: r } }
      .map { |r| augment_repository_root r }
      .map { |r| augment_platform r }
      .map { |r| augment_architecture r }
      .map { |r| augment_path r }.flatten
  end

  def repository_configuration?(configuration)
    configuration['version'] && configuration['repository_root']
  end

  def self.offline
    '-offline' if BUILDPACK_VERSION.offline
  end

  def self.version
    BUILDPACK_VERSION.version || 'unknown'
  end

  ARCHITECTURES = %w[x86_64].freeze

  BUILD_DIR = 'build'

  BUILDPACK_VERSION = JavaBuildpack::BuildpackVersion.new(false).freeze

  PLATFORMS = %w[bionic jammy].freeze

  STAGING_DIR = "#{BUILD_DIR}/staging".freeze

  PACKAGE_NAME = "#{BUILD_DIR}/java-buildpack#{offline}-#{version}.zip".freeze

end
