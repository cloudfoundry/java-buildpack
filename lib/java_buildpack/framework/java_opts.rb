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
        JavaOpts.to_s.dash_case
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile; end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        configured
          .shellsplit
          .map { |java_opt| /(?<key>.+?)=(?<value>.+)/ =~ java_opt ? "#{key}=#{escape_value(value)}" : java_opt }
          .each { |java_opt| @droplet.java_opts << java_opt }

        @droplet.java_opts << '$JAVA_OPTS' if from_environment?

        @droplet.java_opts.as_env_var
      end

      private

      CONFIGURATION_PROPERTY = 'java_opts'.freeze

      ENVIRONMENT_PROPERTY = 'from_environment'.freeze

      private_constant :CONFIGURATION_PROPERTY, :ENVIRONMENT_PROPERTY

      def configured
        @configuration[CONFIGURATION_PROPERTY] || ''
      end

      def escape_value(str)
        return "''" if str.empty?

        str
          .gsub(%r{([^A-Za-z0-9_\-.,:\/@\n$\\])}, '\\\\\\1')
          .gsub(/\n/, "'\n'")
      end

      def from_environment?
        @configuration[ENVIRONMENT_PROPERTY]
      end

    end

  end
end
