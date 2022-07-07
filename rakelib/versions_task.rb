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

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/cache/download_cache'
require 'json'
require 'rake/tasklib'
require 'rakelib/package'
require 'rakelib/utils'
require 'terminal-table'
require 'yaml'

module Package

  # rubocop:disable Metrics/ClassLength
  class VersionsTask < Rake::TaskLib
    include Package

    def initialize
      JavaBuildpack::Logging::LoggerFactory.instance.setup "#{BUILD_DIR}/"

      @pkgcfg = nil

      version_task

      namespace 'versions' do
        version_json_task
        version_markdown_task
        version_yaml_task
      end
    end

    private

    ARCHITECTURE_PATTERN = /\{architecture\}/.freeze

    DEFAULT_REPOSITORY_ROOT_PATTERN = /\{default.repository.root\}/.freeze

    PLATFORM_PATTERN = /\{platform\}/.freeze

    private_constant :ARCHITECTURE_PATTERN, :DEFAULT_REPOSITORY_ROOT_PATTERN, :PLATFORM_PATTERN

    def augment(raw, key, pattern, candidates, &block)
      if raw.respond_to? :at
        raw.map(&block)
      elsif raw[:uri] =~ pattern
        candidates.map do |candidate|
          dup = raw.clone
          dup[key] = candidate
          dup[:uri] = raw[:uri].gsub pattern, candidate

          dup
        end
      else
        raw
      end
    end

    def augment_architecture(raw)
      augment(raw, :architecture, ARCHITECTURE_PATTERN, ARCHITECTURES) { |r| augment_architecture r }
    end

    def augment_path(raw)
      if raw.respond_to? :at
        raw.map { |r| augment_path r }
      else
        raw[:uri] = "#{raw[:uri].chomp('/')}/index.yml"
        raw
      end
    end

    def augment_platform(raw)
      augment(raw, :platform, PLATFORM_PATTERN, PLATFORMS) { |r| augment_platform r }
    end

    def augment_repository_root(raw)
      augment(raw, :repository_root, DEFAULT_REPOSITORY_ROOT_PATTERN, [default_repository_root]) do |r|
        augment_repository_root r
      end
    end

    def component_configuration(component_id)
      configurations(component_id, configuration(component_id))
    end

    def component_ids
      configuration('components').values.flatten.map { |component| component.split('::').last.snake_case }
    end

    def default_repository_root
      configuration('repository')['default_repository_root'].chomp('/')
    end

    def get_from_cache(cache, configuration, index_configuration)
      cache.get(index_configuration[:uri]) do |f|
        index = YAML.safe_load f
        found_version = Utils::VersionUtils.version(configuration, index)

        if found_version.nil?
          raise "Unable to resolve version '#{configuration['version']}' for platform " \
                "'#{index_configuration[:platform]}'"
        end

        return found_version.to_s, index[found_version.to_s]
      end
    end

    def dependency_versions
      dependency_versions = []

      cache = JavaBuildpack::Util::Cache::DownloadCache.new
      configurations = component_ids.map { |component_id| component_configuration(component_id) }.flatten

      configurations.each do |configuration|
        map_config_to_dependency(cache, configuration, dependency_versions)
      end

      dependency_versions
        .uniq { |dependency| dependency['id'] }
        .sort_by { |dependency| dependency['id'] }
    end

    def map_config_to_dependency(cache, configuration, dependency_versions)
      id = configuration['sub_component_id'] || configuration['component_id']

      index_configuration(configuration).each do |index_configuration|
        version, uri = get_from_cache(cache, configuration, index_configuration)

        name = packaging[id]['name']
        raise "Unable to resolve name for '#{id}'" unless name

        dependency_versions << {
          'id' => id,
          'name' => name,
          'uri' => uri,
          'version' => version,
          'cve_link' => packaging[id]['cve_notes'] || '',
          'release_notes_link' => packaging[id]['release_notes'] || ''
        }
      end
    end

    def version_task
      desc 'Display the versions of buildpack dependencies in human readable form'
      task versions: [] do
        v = versions

        rows = v['dependencies']
               .sort_by { |dependency| dependency['name'].downcase }
               .map do |dependency|
          [dependency['name'], dependency['version'], dependency['cve_link'], dependency['release_notes_link']]
        end

        puts Terminal::Table.new title: "Java Buildpack #{v['buildpack']}", rows: rows
      end
    end

    def version_json_task
      desc 'Display the versions of buildpack dependencies in JSON form'
      task json: [] do
        puts JSON.pretty_generate(versions['dependencies']
          .sort_by { |dependency| dependency['name'].downcase })
      end
    end

    def version_markdown_task
      desc 'Display the versions of buildpack dependencies in Markdown form'
      task markdown: [] do
        puts '| Dependency | Version | CVEs | Release Notes |'
        puts '| ---------- | ------- | ---- | ------------- |'

        versions['dependencies']
          .sort_by { |dependency| dependency['name'].downcase }
          .each do |dependency|
          puts "| #{dependency['name']} | `#{dependency['version']}` |" \
               "#{dependency['cve_link']} | #{dependency['release_notes_link']} |"
        end
      end
    end

    def version_yaml_task
      desc 'Display the versions of buildpack dependencies in YAML form'
      task yaml: [] do
        puts YAML.dump(versions)
      end
    end

    def versions
      {
        'buildpack' => Package.version,
        'dependencies' => dependency_versions
      }
    end

  end
  # rubocop:enable Metrics/ClassLength

end
