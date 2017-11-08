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

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/cache/download_cache'
require 'json'
require 'rake/tasklib'
require 'rakelib/package'
require 'terminal-table'
require 'yaml'

module Package

  class VersionsTask < Rake::TaskLib
    include Package

    def initialize
      JavaBuildpack::Logging::LoggerFactory.instance.setup "#{BUILD_DIR}/"

      version_task

      namespace 'versions' do
        version_json_task
        version_markdown_task
        version_yaml_task
      end
    end

    private

    ARCHITECTURE_PATTERN = /\{architecture\}/

    DEFAULT_REPOSITORY_ROOT_PATTERN = /\{default.repository.root\}/

    NAME_MAPPINGS = {
      'access_logging_support'              => 'Tomcat Access Logging Support',
      'agent'                               => 'Java Memory Assistant Agent',
      'app_dynamics_agent'                  => 'AppDynamics Agent',
      'clean_up'                            => 'Java Memory Assistant Clean Up',
      'client_certificate_mapper'           => 'Client Certificate Mapper',
      'container_customizer'                => 'Spring Boot Container Customizer',
      'container_security_provider'         => 'Container Security Provider',
      'contrast_security_agent'             => 'Contrast Security Agent',
      'dyadic_ekm_security_provider'        => 'Dyadic EKM Security Provider',
      'dynatrace_appmon_agent'              => 'Dynatrace Appmon Agent',
      'dynatrace_one_agent'                 => 'Dynatrace OneAgent',
      'geode_store'                         => 'Apache Geode Tomcat Session Store',
      'google_stackdriver_debugger'         => 'Google Stackdriver Debugger',
      'groovy'                              => 'Groovy',
      'introscope_agent'                    => 'CA Introscope APM Framework',
      'jre'                                 => 'OpenJDK JRE',
      'jrebel_agent'                        => 'JRebel Agent',
      'jvmkill_agent'                       => 'jvmkill Agent',
      'lifecycle_support'                   => 'Tomcat Lifecycle Support',
      'logging_support'                     => 'Tomcat Logging Support',
      'luna_security_provider'              => 'Gemalto Luna Security Provider',
      'maria_db_jdbc'                       => 'MariaDB JDBC Driver',
      'memory_calculator'                   => 'Memory Calculator',
      'metric_writer'                       => 'Metric Writer',
      'new_relic_agent'                     => 'New Relic Agent',
      'postgresql_jdbc'                     => 'PostgreSQL JDBC Driver',
      'protect_app_security_provider'       => 'Gemalto ProtectApp Security Provider',
      'redis_store'                         => 'Redis Session Store',
      'spring_auto_reconfiguration'         => 'Spring Auto-reconfiguration',
      'spring_boot_cli'                     => 'Spring Boot CLI',
      'takipi_agent'                        => 'Takipi Agent',
      'tomcat'                              => 'Tomcat',
      'your_kit_profiler'                   => 'YourKit Profiler'
    }.freeze

    PLATFORM_PATTERN = /\{platform\}/

    private_constant :ARCHITECTURE_PATTERN, :DEFAULT_REPOSITORY_ROOT_PATTERN, :NAME_MAPPINGS,
                     :PLATFORM_PATTERN

    def augment(raw, key, pattern, candidates, &block)
      if raw.respond_to? :at
        raw.map(&block)
      elsif raw[:uri] =~ pattern
        candidates.map do |candidate|
          dup       = raw.clone
          dup[key]  = candidate
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

    def configuration(id)
      JavaBuildpack::Util::ConfigurationUtils.load(id, false, false)
    end

    def configurations(component_id, configuration, sub_component_id = nil)
      configurations = []

      if repository_configuration?(configuration)
        configuration['component_id']     = component_id
        configuration['sub_component_id'] = sub_component_id if sub_component_id
        configurations << configuration
      else
        configuration.each { |k, v| configurations << configurations(component_id, v, k) if v.is_a? Hash }
      end

      configurations
    end

    def default_repository_root
      configuration('repository')['default_repository_root'].chomp('/')
    end

    def get_from_cache(cache, configuration, index_configuration)
      cache.get(index_configuration[:uri]) do |f|
        index         = YAML.safe_load f
        found_version = version(configuration, index)

        if found_version.nil?
          raise "Unable to resolve version '#{configuration['version']}' for platform " \
                "'#{index_configuration[:platform]}'"
        end

        return found_version.to_s, index[found_version.to_s]
      end
    end

    def dependency_versions
      dependency_versions = []

      cache          = JavaBuildpack::Util::Cache::DownloadCache.new
      configurations = component_ids.map { |component_id| component_configuration(component_id) }.flatten

      configurations.each do |configuration|
        id = configuration['sub_component_id'] || configuration['component_id']

        index_configuration(configuration).each do |index_configuration|
          version, uri = get_from_cache(cache, configuration, index_configuration)

          name = NAME_MAPPINGS[id]
          raise "Unable to resolve name for '#{id}'" unless name

          dependency_versions << {
            'id'      => id,
            'name'    => name,
            'uri'     => uri,
            'version' => version
          }
        end
      end

      dependency_versions.sort_by { |dependency| dependency['id'] }
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

    def version(configuration, index)
      JavaBuildpack::Repository::VersionResolver
        .resolve(JavaBuildpack::Util::TokenizedVersion.new(configuration['version']), index.keys)
    end

    def version_task
      desc 'Display the versions of buildpack dependencies in human readable form'
      task versions: [] do
        v = versions

        rows = v['dependencies']
               .sort_by { |dependency| dependency['name'].downcase }
               .map { |dependency| [dependency['name'], dependency['version']] }

        puts Terminal::Table.new title: "Java Buildpack #{v['buildpack']}", rows: rows
      end
    end

    def version_json_task
      desc 'Display the versions of buildpack dependencies in JSON form'
      task json: [] do
        puts JSON.pretty_generate(versions['dependencies']
          .sort_by { |dependency| dependency['name'].downcase }
          .map { |dependency| "#{dependency['name']} #{dependency['version']}" })
      end
    end

    def version_markdown_task
      desc 'Display the versions of buildpack dependencies in Markdown form'
      task markdown: [] do
        puts '| Dependency | Version |'
        puts '| ---------- | ------- |'

        versions['dependencies']
          .sort_by { |dependency| dependency['name'].downcase }
          .each { |dependency| puts "| #{dependency['name']} | `#{dependency['version']}` |" }
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
        'buildpack'    => Package.version,
        'dependencies' => dependency_versions
      }
    end

  end

end
