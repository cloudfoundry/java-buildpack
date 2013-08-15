# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/util/properties'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+ method.
  # This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle of Java
  # +main()+ applications.
  class Main

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [String] :java_home the directory that acts as +JAVA_HOME+
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @app_dir = context[:app_dir]
      @java_home = context[:java_home]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
      @configuration = context[:configuration]
    end

    # Detects whether this application is Java +main()+ application.
    #
    # @return [String] returns +java-main+ if:
    #                  * a +java.main.class+ system property is set by the user
    #                  * a +META-INF/MANIFEST.MF+ file exists and has a +Main-Class+ attribute
    def detect
      main_class ? CONTAINER_NAME : nil
    end

    # Does nothing as no transformations are required when running Java +main()+ applications.
    #
    # @return [void]
    def compile
    end

    # Creates the command to run the Java +main()+ application.
    #
    # @return [String] the command to run the application.
    def release
      java_string = File.join @java_home, 'bin', 'java'
      classpath_string = ContainerUtils.space(classpath(@app_dir, @lib_directory))
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@java_opts))
      main_class_string = ContainerUtils.space(main_class)
      arguments_string = ContainerUtils.space(arguments)
      port_string = ContainerUtils.space(port)

      "#{java_string}#{classpath_string}#{java_opts_string}#{main_class_string}#{arguments_string}#{port_string}"
    end

    private

      MAIN_CLASS_PROPERTY = 'java_main_class'.freeze

      ARGUMENTS_PROPERTY = 'arguments'.freeze

      CLASS_PATH_PROPERTY = 'Class-Path'.freeze

      CONTAINER_NAME = 'java-main'.freeze

      MANIFEST_PROPERTY = 'Main-Class'.freeze

      def arguments
        @configuration[ARGUMENTS_PROPERTY]
      end

      def classpath(app_dir, lib_directory)
        classpath = ['.']
        classpath.concat ContainerUtils.libs(app_dir, lib_directory)
        classpath.concat manifest_class_path

        "-cp #{classpath.join(':')}"
      end

      def main_class
        @configuration[MAIN_CLASS_PROPERTY] || manifest[MANIFEST_PROPERTY]
      end

      def manifest
        manifest_file = File.join(@app_dir, 'META-INF', 'MANIFEST.MF')
        manifest_file = File.exists?(manifest_file) ? manifest_file : nil
        JavaBuildpack::Util::Properties.new(manifest_file)
      end

      def manifest_class_path
        value = manifest[CLASS_PATH_PROPERTY]
        value.nil? ? [] : value.split(' ')
      end

      def port
        main_class =~ /^org\.springframework\.boot\.loader\.[JW]arLauncher$/ ? '--server.port=$PORT' : nil
      end

  end

end
