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

require 'fileutils'
require 'java_buildpack/component'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/component/droplet'
require 'java_buildpack/component/environment_variables'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the integraton of the JavaMemoryAssistant to inject the agent in the JVM.
    class JavaMemoryAssistantAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
                .add_javaagent(@droplet.sandbox + jar_name)
                .add_system_property('jma.enabled', 'true')
                .add_system_property('jma.heap_dump_name', %("#{name_pattern}"))
                .add_system_property 'jma.log_level', normalized_log_level

        add_system_prop_if_config_present 'check_interval', 'jma.check_interval'
        add_system_prop_if_config_present 'max_frequency', 'jma.max_frequency'

        return unless @configuration.key?('thresholds')

        @configuration['thresholds'].each do |key, value|
          @droplet.java_opts.add_system_property "jma.thresholds.#{key}", value.to_s
        end
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#jar_name)
      def jar_name
        "java-memory-assistant-#{@version}.jar"
      end

      def supports?
        true
      end

      private

      LOG_LEVEL_MAPPING = {
        'DEBUG' => 'DEBUG',
        'WARN' => 'WARNING',
        'INFO' => 'INFO',
        'ERROR' => 'ERROR',
        'FATAL' => 'ERROR'
      }.freeze

      private_constant :LOG_LEVEL_MAPPING

      def add_system_prop_if_config_present(config_entry, system_property_name)
        return unless @configuration.key?(config_entry)
        @droplet.java_opts.add_system_property(system_property_name, @configuration[config_entry])
      end

      def log_level
        @configuration['log_level'] || ENV['JBP_LOG_LEVEL'] || 'ERROR'
      end

      def normalized_log_level
        normalized_log_level = LOG_LEVEL_MAPPING[log_level.upcase]
        raise "Invalid value of the 'log_level' property: '#{log_level}'" unless normalized_log_level
        normalized_log_level
      end

      def name_pattern
        # Double escaping quotes of doom. Nothing less would work.
        %q(%env:CF_INSTANCE_INDEX%-%ts:yyyy-MM-dd'"'"'T'"'"'mm'"'"':'"'"'ss'"'"':'"'"'SSSZ%-) \
          '%env:CF_INSTANCE_GUID[,8]%.hprof'
      end

    end
  end
end
