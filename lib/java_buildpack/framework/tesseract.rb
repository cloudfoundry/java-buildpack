# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

    class Tesseract < JavaBuildpack::Component::BaseComponent

      def detect
        true
        #logger = Logging::LoggerFactory.instance.get_logger Buildpack
        #logger.debug { "************got into my detect *********" }
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        with_timing "Expanding tesseract ocr" do
          @droplet.copy_resources
          shell "mkdir #{@droplet.sandbox}/vendor"
          shell "tar xzf #{@droplet.sandbox}/tesseract-archive.tar.gz -C #{@droplet.sandbox}/vendor --strip-components=1 2>&1"

        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        #shell "export PATH=\"#{@droplet.sandbox}/vendor:\$PATH\""
        #credentials = @application.services.find_service(FILTER)['credentials']
        #java_opts   = @droplet.java_opts
        #configuration = {}

        #apply_configuration(credentials, configuration)
        #apply_user_configuration(credentials, configuration)
        #write_java_opts(java_opts, configuration)

        #java_opts.add_javaagent(@droplet.sandbox + jar_name)
        #         .add_system_property('newrelic.home', @droplet.sandbox)
        #java_opts.add_system_property('newrelic.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
        @droplet.environment_variables.add_environment_variable 'PATH', "#{@droplet.sandbox}/vendor:$PATH"
        @droplet.environment_variables.add_environment_variable 'LD_LIBRARY_PATH', "#{@droplet.sandbox}/vendor:$PATH"
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      # private

      # FILTER = /newrelic/.freeze

      # LICENSE_KEY = 'licenseKey'.freeze

      # LICENSE_KEY_USER = 'license_key'.freeze

      # private_constant :FILTER, :LICENSE_KEY, :LICENSE_KEY_USER

      # def apply_configuration(credentials, configuration)
      #   configuration['log_file_name'] = 'STDOUT'
      #   configuration[LICENSE_KEY_USER] = credentials[LICENSE_KEY]
      #   configuration['app_name'] = @application.details['space_name'].concat('-').concat(@application.details['application_name'])
      # end

      # def apply_user_configuration(credentials, configuration)
      #   credentials.each do |key, value|
      #     configuration[key] = value
      #   end
      # end

      # def write_java_opts(java_opts, configuration)
      #   configuration.each do |key, value|
      #     java_opts.add_system_property("newrelic.config.#{key}", value)
      #   end
      # end

    end

  end
end
