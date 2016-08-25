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

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'
require 'shellwords'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing custom Java options to an application.
    class JavaOpts < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports_configuration? || supports_environment? ? JavaOpts.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        parsed_java_opts.each do |option|
          if memory_option? option
            raise "Java option '#{option}' configures a memory region.  Use JRE configuration for this instead."
          end
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.concat parsed_java_opts
      end

      private

      CONFIGURATION_PROPERTY = 'java_opts'.freeze

      ENVIRONMENT_PROPERTY = 'from_environment'.freeze

      ENVIRONMENT_VARIABLE = 'JAVA_OPTS'.freeze

      private_constant :CONFIGURATION_PROPERTY, :ENVIRONMENT_PROPERTY, :ENVIRONMENT_VARIABLE

      def memory_option?(option)
        option =~ /-Xms/ || option =~ /-Xmx/ || option =~ /-XX:MaxMetaspaceSize/ || option =~ /-XX:MaxPermSize/ ||
          option =~ /-Xss/ || option =~ /-XX:MetaspaceSize/ || option =~ /-XX:PermSize/
      end

      def parsed_java_opts
        parsed_java_opts = []

        parsed_java_opts.concat @configuration[CONFIGURATION_PROPERTY].shellsplit if supports_configuration?
        parsed_java_opts.concat ENV[ENVIRONMENT_VARIABLE].shellsplit if supports_environment?

        parsed_java_opts.map do |java_opt|
          if /(?<key>.+?)=(?<value>.+)/ =~ java_opt
            "#{key}=#{parse_shell_string(value)}"
          else
            java_opt
          end
        end
      end

      def parse_shell_string(str)
        return "''" if str.empty?
        str = str.dup
        str.gsub!(%r{([^A-Za-z0-9_\-.,:\/@\n$\\])}, '\\\\\\1')
        str.gsub!(/\n/, "'\n'")
        str
      end

      def supports_configuration?
        @configuration.key?(CONFIGURATION_PROPERTY) && !@configuration[CONFIGURATION_PROPERTY].nil?
      end

      def supports_environment?
        @configuration[ENVIRONMENT_PROPERTY] && ENV.key?(ENVIRONMENT_VARIABLE)
      end

    end

  end
end
