# Encoding: utf-8
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

    # Encapsulates the integraton of the JavaMemoryAssistant.
    class JavaMemoryAssistant < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used by the component
      def initialize(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger JavaMemoryAssistant
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        setup_log_level

        @droplet.java_opts.add_javaagent @droplet.sandbox + jar_name

        add_basic_props

        add_system_prop_if_config_present 'heap_dump_folder', 'jma.heap_dump_folder', true
        add_system_prop_if_config_present 'check_interval', 'jma.check_interval'
        add_system_prop_if_config_present 'max_frequency', 'jma.max_frequency'

        setup_upload
        setup_dump_cleanup

        @droplet.java_opts.add_system_property 'jma.log_level', @log_level

        (@configuration['thresholds'] || {}).each do |key, value|
          @droplet.java_opts.add_system_property "jma.thresholds.#{key}", value.to_s
        end
      end

      protected

      def supports?
        @configuration['enabled']
      end

      private

      def setup_log_level
        @log_level = mapped_log_level @configuration['log_level'] || @application.environment['LOG_LEVEL'] || 'ERROR'
      end

      S3_FILTER = 'jma_upload_S3'.freeze

      def add_basic_props
        @droplet.java_opts.add_system_property 'jma.enabled', 'true'
        @droplet.java_opts.add_system_property 'jma.heap_dump_name', name_pattern
      end

      def name_pattern
        "#{@application.details['space_id'][0, 6]}_" \
          "#{@application.details['application_name']}_" \
          '%env:CF_INSTANCE_INDEX%_' \
          '%ts:yyyyMMddmmssSS%_' \
          '%env:CF_INSTANCE_GUID%' \
          '.hprof'
      end

      def setup_upload
        setup_upload_to_s3
      end

      def setup_upload_to_s3
        service = @application.services.find_service(S3_FILTER)

        unless service
          @logger.debug { "No '#{S3_FILTER}' service bound, skipping S3 upload" }
          return
        end

        credentials = service['credentials']

        raise "No credentials are available for the '#{S3_FILTER}' service bound to this application" unless credentials

        configure_upload_to_s3 credentials
      end

      def configure_upload_to_s3(credentials)
        bucket = get_value_or_raise credentials, 'bucket'
        region = get_value_or_raise credentials, 'region'
        key = get_value_or_raise credentials, 'key'
        secret = get_value_or_raise credentials, 'secret'
        keep_in_container = credentials['keep_in_container'] || false
        log = @log_level != 'ERROR'

        File.open(@droplet.sandbox + 's3.config', 'w+') do |file|
          file.write("BUCKET='#{bucket}'\nAWS_ACCESS_KEY='#{key}'\n" \
            "AWS_SECRET_KEY='#{secret}'\nAWS_REGION='#{region}'\n" \
            "LOG=#{log}\nKEEP_IN_CONTAINER=#{keep_in_container}\n")
        end

        @droplet.java_opts.add_system_property('jma.execute.after', @droplet.sandbox + 'bin/upload-to-s3.sh')
        @droplet.java_opts.add_system_property('jma.execute.on_shutdown', @droplet.sandbox + 'bin/kill-upload-to-s3.sh')

        @logger.info { "Upload of heap dumps configured to S3 bucket '#{bucket}'" }
      end

      def get_value_or_raise(credentials, property)
        value = credentials[property]
        raise "No '#{property}' entry found in the credentials for the '#{S3_FILTER}' service" unless value
        value
      end

      def setup_dump_cleanup
        return unless @configuration['max_dump_count']

        File.open(@droplet.sandbox + 'max_dump_count', 'w+') { |f| f.write(@configuration['max_dump_count']) }

        @droplet.java_opts.add_system_property('jma.command.interpreter', '/bin/sh')
        @droplet.java_opts.add_system_property('jma.execute.before', @droplet.sandbox + 'bin/clean-up.sh')
      end

      def add_system_prop_if_config_present(config_entry, system_property_name, quote_value = false)
        return unless @configuration[config_entry]

        config_value = @configuration[config_entry]
        config_value = '"' + config_value + '"' if quote_value

        @droplet.java_opts.add_system_property(system_property_name, config_value) if config_value
      end

      def mapped_log_level(log_level)
        return unless log_level

        mapped_log_level = log_level_mapping[log_level]

        raise "Invalid value of the 'log_level' property: '#{log_level}'" unless mapped_log_level

        mapped_log_level
      end

      def log_level_mapping
        {
          'DEBUG' => 'DEBUG',
          'WARN' => 'WARNING',
          'INFO' => 'INFO',
          'ERROR' => 'ERROR',
          'FATAL' => 'ERROR'
        }
      end

    end
  end
end
