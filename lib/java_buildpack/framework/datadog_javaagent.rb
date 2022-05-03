# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2021 the original author or authors.
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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Elastic APM support.
    class DatadogJavaagent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger DatadogJavaagent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @logger.error 'Datadog Buildpack is required, but not found' unless datadog_buildpack?

        return unless datadog_buildpack?

        download_jar
        fix_class_count
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return unless datadog_buildpack?

        java_opts = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + jar_name)

        unless @application.environment.key?('DD_SERVICE')
          app_name = @configuration['default_application_name'] || @application.details['application_name']
          java_opts.add_system_property('dd.service', "\\\"#{app_name}\\\"")
        end

        version = @application.environment['DD_VERSION'] || @configuration['default_application_version'] ||
          @application.details['application_version']
        java_opts.add_system_property('dd.version', version)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        api_key_defined = @application.environment.key?('DD_API_KEY') && !@application.environment['DD_API_KEY'].empty?
        apm_disabled = @application.environment['DD_APM_ENABLED'] == 'false'
        (api_key_defined && !apm_disabled)
      end

      # determins if the datadog buildpack is present
      def datadog_buildpack?
        File.exist?(File.join(@droplet.root, '.datadog')) || File.exist?(File.join(@droplet.root, 'datadog'))
      end

      # fixes issue where some classes are not counted by adding shadow class files
      def fix_class_count
        cnt = classdata_count(@droplet.sandbox + jar_name)
        zipdir = "#{@droplet.sandbox}/datadog_fakeclasses"
        zipfile = "#{@droplet.sandbox}/datadog_fakeclasses.jar"

        File.delete(zipfile) if File.exist? zipfile
        FileUtils.rm_rf(zipdir)
        FileUtils.mkdir_p(zipdir)

        1.upto(cnt) do |i|
          File.open("#{zipdir}/#{i}.class", 'w') do |f|
            File.write(f, i.to_s)
          end
        end

        `cd #{zipdir} && zip -r #{zipfile} .`
        FileUtils.rm_rf(zipdir)
      end

      # count hidden class files in the agent JAR
      def classdata_count(archive)
        `unzip -l #{archive} | grep '\\(\\.classdata\\)$' | wc -l`.to_i
      end
    end
  end
end
