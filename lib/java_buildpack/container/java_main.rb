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
require 'java_buildpack/container'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/util/qualify_path'
require 'java_buildpack/util/spring_boot_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+
    # method. This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle
    # of Java +main()+ applications.
    class JavaMain < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @spring_boot_utils = JavaBuildpack::Util::SpringBootUtils.new
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        main_class ? JavaMain.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        return unless @spring_boot_utils.is?(@application)
        @droplet.additional_libraries.link_to(@spring_boot_utils.lib(@droplet))
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        manifest_class_path.each { |path| @droplet.additional_libraries << path }

        if @spring_boot_utils.is?(@application)
          @droplet.environment_variables.add_environment_variable 'SERVER_PORT', '$PORT'
        else
          @droplet.additional_libraries.insert 0, @application.root
        end

        classpath = @spring_boot_utils.is?(@application) ? '-cp $PWD/.' : @droplet.additional_libraries.as_classpath
        release_text(classpath)
      end

      private

      ARGUMENTS_PROPERTY = 'arguments'.freeze

      CLASS_PATH_PROPERTY = 'Class-Path'.freeze

      private_constant :ARGUMENTS_PROPERTY, :CLASS_PATH_PROPERTY

      def release_text(classpath)
        [
          @droplet.java_opts.as_env_var,
          '&&',
          @droplet.environment_variables.as_env_vars,
          'eval',
          'exec',
          "#{qualify_path @droplet.java_home.root, @droplet.root}/bin/java",
          '$JAVA_OPTS',
          classpath,
          main_class,
          arguments
        ].flatten.compact.join(' ')
      end

      def arguments
        @configuration[ARGUMENTS_PROPERTY]
      end

      def main_class
        JavaBuildpack::Util::JavaMainUtils.main_class(@application, @configuration)
      end

      def manifest_class_path
        values = JavaBuildpack::Util::JavaMainUtils.manifest(@application)[CLASS_PATH_PROPERTY]
        values.nil? ? [] : values.split(' ').map { |value| @droplet.root + value }
      end

    end

  end
end
