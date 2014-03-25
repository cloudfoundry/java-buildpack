# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2014 the original author or authors.
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

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/cache/download_cache'
require 'java_buildpack/util/snake_case'
require 'offline'
require 'pathname'
require 'yaml'

module Offline

  class DependencyCacheTask < Rake::TaskLib
    include Offline

    attr_reader :targets

    def initialize
      JavaBuildpack::Logging::LoggerFactory.setup "#{BUILD_DIR}/"

      @default_repository_root = configuration('repository')['default_repository_root'].chomp('/')
      @cache                   = cache

      configurations = component_ids.map { |component_id| configurations(configuration(component_id)) }.flatten
      @targets       = uris(configurations).each { |uri| create_task(uri) }
    end

  end

  private

  ARCHITECTURE_PATTERN = /\{architecture\}/.freeze

  DEFAULT_REPOSITORY_ROOT_PATTERN = /\{default.repository.root\}/.freeze

  PLATFORM_PATTERN = /\{platform\}/.freeze

  def augment_architecture(raw)
    if raw.respond_to? :map
      raw.map { |r| augment_architecture r }
    else
      raw =~ ARCHITECTURE_PATTERN ? ARCHITECTURES.map { |p| raw.gsub ARCHITECTURE_PATTERN, p } : raw
    end
  end

  def augment_path(raw)
    if raw.respond_to? :map
      raw.map { |r| augment_path r }
    else
      "#{raw.chomp('/')}/index.yml"
    end
  end

  def augment_platform(raw)
    if raw.respond_to? :map
      raw.map { |r| augment_platform r }
    else
      raw =~ PLATFORM_PATTERN ? PLATFORMS.map { |p| raw.gsub PLATFORM_PATTERN, p } : raw
    end
  end

  def augment_repository_root(raw)
    if raw.respond_to? :map
      raw.map { |r| augment_repository_root r }
    else
      raw.gsub DEFAULT_REPOSITORY_ROOT_PATTERN, @default_repository_root
    end
  end

  def cache
    JavaBuildpack::Util::Cache::DownloadCache.new(Pathname.new("#{STAGING_DIR}/resources/cache")).freeze
  end

  def component_ids
    configuration('components').values.flatten.map { |component| component.split('::').last.snake_case }
  end

  def configuration(id)
    JavaBuildpack::Util::ConfigurationUtils.load(id, false)
  end

  def configurations(configuration)
    configurations = []

    if repository_configuration?(configuration)
      configurations << configuration
    else
      configurations << configuration.values.map { |v| configurations(v) }
    end

    configurations
  end

  def index_uris(configuration)
    [configuration['repository_root']]
    .map { |r| augment_repository_root r }
    .map { |r| augment_platform r }
    .map { |r| augment_architecture r }
    .map { |r| augment_path r }.flatten
  end

  def repository_configuration?(configuration)
    configuration['version'] && configuration['repository_root']
  end

  def uris(configurations)
    uris = []

    configurations.each do |configuration|
      index_uris(configuration).each do |index_uri|
        @cache.get(index_uri) do |file|
          index = YAML.load(file)
          uris << index[version(configuration, index).to_s]
        end
      end
    end

    uris
  end

  def version(configuration, index)
    JavaBuildpack::Repository::VersionResolver.resolve(JavaBuildpack::Util::TokenizedVersion.new(configuration['version']), index.keys)
  end

  def create_task(uri)
    task uri do |t|
      puts "Caching #{t.name}"
      cache.get(t.name)
    end

    uri
  end

end
