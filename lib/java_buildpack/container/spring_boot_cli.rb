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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/file_enumerable'
require 'java_buildpack/util/groovy_utils'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running Spring Boot CLI
    # applications.
    class SpringBootCLI < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger SpringBootCLI
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables
                .add_environment_variable('JAVA_OPTS', '$JAVA_OPTS')
                .add_environment_variable('SERVER_PORT', '$PORT')

        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          qualify_path(@droplet.sandbox + 'bin/spring', @droplet.root),
          'run',
          @droplet.additional_libraries.as_classpath,
          relative_groovy_files
        ].flatten.compact.join(' ')
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        gf = JavaBuildpack::Util::GroovyUtils.groovy_files(@application).reject { |file| logback_file? file }
        !gf.empty? && all_pogo_or_configuration(gf) && no_main_method(gf) && no_shebang(gf) && !web_inf?
      end

      private

      def relative_groovy_files
        JavaBuildpack::Util::GroovyUtils.groovy_files(@application).map do |gf|
          gf.relative_path_from(@application.root)
        end
      end

      def logback_file?(path)
        %r{ch/qos/logback/.*\.groovy$} =~ path.to_s
      end

      def no_main_method(groovy_files)
        none?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file }
      end

      def no_shebang(groovy_files)
        none?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.shebang? file }
      end

      def web_inf?
        (@application.root + 'WEB-INF').exist?
      end

      def all_pogo_or_configuration(groovy_files)
        all?(groovy_files) do |file|
          JavaBuildpack::Util::GroovyUtils.pogo?(file) || JavaBuildpack::Util::GroovyUtils.beans?(file)
        end
      end

    end

  end
end
