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
require 'terminal-table'
require 'yaml'

module Package

  # rubocop:disable Metrics/ClassLength
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

    ARCHITECTURE_PATTERN = /\{architecture\}/.freeze

    DEFAULT_REPOSITORY_ROOT_PATTERN = /\{default.repository.root\}/.freeze

    NAME_MAPPINGS = {
      'access_logging_support' => 'Tomcat Access Logging Support',
      'agent' => 'Java Memory Assistant Agent',
      'app_dynamics_agent' => 'AppDynamics Agent',
      'azure_application_insights_agent' => 'Azure Application Insights Agent',
      'clean_up' => 'Java Memory Assistant Clean Up',
      'client_certificate_mapper' => 'Client Certificate Mapper',
      'container_customizer' => 'Spring Boot Container Customizer',
      'container_security_provider' => 'Container Security Provider',
      'contrast_security_agent' => 'Contrast Security Agent',
      'datadog_javaagent' => 'Datadog APM Javaagent',
      'dynatrace_one_agent' => 'Dynatrace OneAgent',
      'elastic_apm_agent' => 'Elastic APM Agent',
      'geode_store' => 'Geode Tomcat Session Store',
      'google_stackdriver_debugger' => 'Google Stackdriver Debugger',
      'google_stackdriver_profiler' => 'Google Stackdriver Profiler',
      'groovy' => 'Groovy',
      'introscope_agent' => 'CA Introscope APM Framework',
      'jacoco_agent' => 'JaCoCo Agent',
      'jprofiler_profiler' => 'JProfiler Profiler',
      'jre' => 'OpenJDK JRE',
      'jre-11' => 'OpenJDK JRE 11',
      'jre-17' => 'OpenJDK JRE 17',
      'jrebel_agent' => 'JRebel Agent',
      'jvmkill_agent' => 'jvmkill Agent',
      'lifecycle_support' => 'Tomcat Lifecycle Support',
      'logging_support' => 'Tomcat Logging Support',
      'luna_security_provider' => 'Gemalto Luna Security Provider',
      'maria_db_jdbc' => 'MariaDB JDBC Driver',
      'memory_calculator' => 'Memory Calculator',
      'metric_writer' => 'Metric Writer',
      'new_relic_agent' => 'New Relic Agent',
      'postgresql_jdbc' => 'PostgreSQL JDBC Driver',
      'protect_app_security_provider' => 'Gemalto ProtectApp Security Provider',
      'redis_store' => 'Redis Session Store',
      'riverbed_appinternals_agent' => 'Riverbed Appinternals Agent',
      'sealights_agent' => 'SeaLights Agent',
      'sky_walking_agent' => 'SkyWalking',
      'spring_auto_reconfiguration' => 'Spring Auto-reconfiguration',
      'spring_boot_cli' => 'Spring Boot CLI',
      'takipi_agent' => 'Takipi Agent',
      'tomcat' => 'Tomcat',
      'your_kit_profiler' => 'YourKit Profiler'
    }.freeze

    NOTE_LINKS = {
      'access_logging_support' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'agent' => { 'cve' => '', 'release' => '' },
      'app_dynamics_agent' => {
        'cve' => '',
        'release' => '[Release Notes](https://docs.appdynamics.com/4.5.x/en/product-and-' \
                     'release-announcements/release-notes/language-agent-notes/java-agent-notes)'
      },
      'azure_application_insights_agent' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://github.com/Microsoft/ApplicationInsights-Java/releases)' },
      'clean_up' => { 'cve' => '', 'release' => '' },
      'client_certificate_mapper' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'container_customizer' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'container_security_provider' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'contrast_security_agent' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://docs.contrastsecurity.com/en/java-agent-release-notes.html)' },
      'datadog_javaagent' => { 'cve' => '',
                               'release' => '[Release Notes](https://github.com/DataDog/dd-trace-java/releases)' },
      'dynatrace_one_agent' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://www.dynatrace.com/support/help/whats-new/release-notes/#oneagent)' },
      'elastic_apm_agent' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://www.elastic.co/guide/en/apm/agent/java/current/release-notes.html)' },
      'geode_store' => { 'cve' => '', 'release' => '' },
      'google_stackdriver_debugger' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://cloud.google.com/debugger/docs/release-notes)' },
      'google_stackdriver_profiler' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://cloud.google.com/profiler/docs/release-notes)' },
      'groovy' => { 'cve' => '', 'release' => '[Release Notes](http://www.groovy-lang.org/releases.html)' },
      'introscope_agent' => { 'cve' => '', 'release' => '' },
      'jacoco_agent' => { 'cve' => '', 'release' => '[Release Notes](https://github.com/jacoco/jacoco/releases)' },
      'jprofiler_profiler' =>
        { 'cve' => '',
          'release' => '[ChangeLog](https://www.ej-technologies.com/download/jprofiler/changelog.html)' },
      'jre' => { 'cve' => '[Risk Matrix](https://www.oracle.com/security-alerts/cpuapr2022.html#AppendixJAVA)',
                 'release' => '[Release Notes](https://bell-sw.com/pages/liberica-release-notes-8u332/)' },
      'jre-11' => { 'cve' => '[Risk Matrix](https://www.oracle.com/security-alerts/cpuapr2022.html#AppendixJAVA)',
                    'release' => '[Release Notes](https://bell-sw.com/pages/liberica-release-notes-11.0.15/)' },
      'jre-17' => { 'cve' => '[Risk Matrix](https://www.oracle.com/security-alerts/cpuapr2022.html#AppendixJAVA)',
                    'release' => '[Release Notes](https://bell-sw.com/pages/liberica-release-notes-17.0.3/)' },
      'jrebel_agent' => { 'cve' => '', 'release' => '[ChangeLog](https://www.jrebel.com/products/jrebel/changelog)' },
      'jvmkill_agent' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'lifecycle_support' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'logging_support' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'luna_security_provider' =>
        { 'cve' => '',
          'release' =>
            '[Release Notes](https://www.thalesdocs.com/gphsm/luna/7/docs/network/Content/CRN/Luna/CRN_Luna.htm)' },
      'maria_db_jdbc' =>
        { 'cve' => '',
          'release' => '[Release Notes](https://mariadb.com/kb/en/mariadb-connector-j-274-release-notes/)' },
      'memory_calculator' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'metric_writer' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'new_relic_agent' =>
        { 'cve' => '',
          'release' =>
            '[Release Notes](https://docs.newrelic.com/docs/release-notes/agent-release-notes/java-release-notes/)' },
      'postgresql_jdbc' => { 'cve' => '',
                             'release' => '[ChangeLog](https://jdbc.postgresql.org/documentation/changelog.html)' },
      'protect_app_security_provider' => { 'cve' => '', 'release' => '' },
      'redis_store' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'riverbed_appinternals_agent' => { 'cve' => '', 'release' => '' },
      'sealights_agent' => { 'cve' => '', 'release' => '' },
      'sky_walking_agent' => { 'cve' => '',
                               'release' => '[ChangeLog](https://github.com/apache/skywalking/tree/master/changes)' },
      'spring_auto_reconfiguration' => { 'cve' => 'Included inline above', 'release' => 'Included inline above' },
      'spring_boot_cli' => { 'cve' => '', 'release' => '' },
      'takipi_agent' => { 'cve' => '', 'release' => '[Release Notes](https://doc.overops.com/docs/whats-new)' },
      'tomcat' => { 'cve' => '[Security](https://tomcat.apache.org/security-9.html)',
                    'release' => '[ChangeLog](https://tomcat.apache.org/tomcat-9.0-doc/changelog.html)' },
      'your_kit_profiler' => { 'cve' => '',
                               'release' => '[Release Notes](https://www.yourkit.com/download/yjp_2022_3_builds.jsp)' }
    }.freeze

    PLATFORM_PATTERN = /\{platform\}/.freeze

    private_constant :ARCHITECTURE_PATTERN, :DEFAULT_REPOSITORY_ROOT_PATTERN, :NAME_MAPPINGS,
                     :PLATFORM_PATTERN, :NOTE_LINKS

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

    def configuration(id)
      JavaBuildpack::Util::ConfigurationUtils.load(id, false, false)
    end

    def configurations(component_id, configuration, sub_component_id = nil)
      configurations = []

      if repository_configuration?(configuration)
        configuration['component_id'] = component_id
        configuration['sub_component_id'] = sub_component_id if sub_component_id

        if component_id == 'open_jdk_jre' && sub_component_id == 'jre'
          c1 = configuration.clone
          c1['sub_component_id'] = 'jre-11'
          c1['version'] = '11.+'

          configurations << c1
        end

        if component_id == 'open_jdk_jre' && sub_component_id == 'jre'
          c1 = configuration.clone
          c1['sub_component_id'] = 'jre-17'
          c1['version'] = '17.+'

          configurations << c1
        end
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
        index = YAML.safe_load f
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

        name = NAME_MAPPINGS[id]
        raise "Unable to resolve name for '#{id}'" unless name

        dependency_versions << {
          'id' => id,
          'name' => name,
          'uri' => uri,
          'version' => version,
          'cve_link' => NOTE_LINKS[id]['cve'],
          'release_notes_link' => NOTE_LINKS[id]['release']
        }
      end
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
