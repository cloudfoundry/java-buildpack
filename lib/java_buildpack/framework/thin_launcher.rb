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
require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling the Thin Launcher
    class ThinLauncher < JavaBuildpack::Component::BaseComponent

      # Creates a new instance
      def initialize(context)
        super(context)
        @logger = Logging::LoggerFactory.instance.get_logger ThinLauncher
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @logger.debug { "Resolving dependencies to #{File.join(ENV['HOME'], '.m2')}..." }
        lib = File.join(@droplet.root,"lib")
        Dir.exist?(lib) || Dir.mkdir(lib)
        shell [
          @droplet.java_opts.as_env_var,
          '&&',
          @droplet.environment_variables.as_env_vars,
          'eval',
          'exec',
          "#{@droplet.java_home.root}/bin/java",
          '-Ddebug=true',
          '$JAVA_OPTS',
          "-cp #{@droplet.root}/.",
          main_class,
          '--thin.dryrun',
          arguments
        ].flatten.compact.join(' ')
        @logger.debug { "Resolved dependencies" }
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        main = main_class
        main && main.end_with?('ThinJarWrapper') ? ThinLauncher.to_s.dash_case : nil
      end

      ARGUMENTS_PROPERTY = 'arguments'.freeze

      private_constant :ARGUMENTS_PROPERTY

      def arguments
        @configuration[ARGUMENTS_PROPERTY]
      end

      def main_class
        JavaBuildpack::Util::JavaMainUtils.main_class(@application, @configuration)
      end

    end

  end
end
