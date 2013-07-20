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

require 'fileutils'
require 'java_buildpack'
require 'java_buildpack/util/constantize'
require 'java_buildpack/util/logger'
require 'pathname'
require 'time'
require 'yaml'

module JavaBuildpack

  # Encapsulates the detection, compile, and release functionality for Java application
  class Buildpack

    # Creates a new instance, passing in the application directory.  As part of initialization, all of files located in
    # the following directories are +require+d:
    # * +lib/java_buildpack/container+
    # * +lib/java_buildpack/jre+
    # * +lib/java_buildpack/framework+
    #
    # @param [String] app_dir The application directory
    def initialize(app_dir)
      @logger = JavaBuildpack::Util::Logger.new(app_dir)

      Buildpack.dump_environment_variables @logger
      Buildpack.require_component_files
      components = Buildpack.components @logger

      java_home = ''
      java_opts = []
      @lib_directory = Buildpack.lib_directory app_dir

      basic_context = {
        app_dir: app_dir,
        java_home: java_home,
        java_opts: java_opts,
        lib_directory: @lib_directory,
        diagnostics: { directory: JavaBuildpack::Util::Logger::DIAGNOSTICS_DIRECTORY }
      }

      @jres = Buildpack.construct_components(components, 'jres', basic_context, @logger)

      @frameworks = Buildpack.construct_components(components, 'frameworks', basic_context, @logger)

      @containers = Buildpack.construct_components(components, 'containers', basic_context, @logger)
    end

    # Iterates over all of the components to detect if this buildpack can be used to run an application
    #
    # @return [Array<String>] An array of strings that identify the components and versions that will be used to run
    #                         this application.  If no container can run the application, the array will be empty
    #                         (+[]+).
    def detect
      jre_detections = Buildpack.component_detections @jres
      raise "Application can be run using more than one JRE: #{jre_detections.join(', ')}" if jre_detections.size > 1

      framework_detections = Buildpack.component_detections @frameworks

      container_detections = Buildpack.component_detections @containers
      raise "Application can be run by more than one container: #{container_detections.join(', ')}" if container_detections.size > 1

      tags = container_detections.empty? ? [] : jre_detections.concat(framework_detections).concat(container_detections).flatten.compact
      @logger.log('Detection Tags', tags)
      tags
    end

    # Transforms the application directory such that the JRE, container, and frameworks can run the application
    #
    # @return [void]
    def compile
      FileUtils.mkdir_p @lib_directory

      jre.compile
      frameworks.each { |framework| framework.compile }
      container.compile
    end

    # Generates the payload required to run the application.  The payload format is defined by the
    # {Heroku Buildpack API}[https://devcenter.heroku.com/articles/buildpack-api#buildpack-api].
    #
    # @return [String] The payload required to run the application.
    def release
      jre.release
      frameworks.each { |framework| framework.release }
      command = container.release

      payload = {
        'addons' => [],
        'config_vars' => {},
        'default_process_types' => {
          'web' => command
        }
      }.to_yaml

      @logger.log('Release Payload', payload)

      payload
    end

    private

      COMPONENTS_CONFIG = '../../config/components.yml'.freeze

      LIB_DIRECTORY = '.lib'

      def self.dump_environment_variables(logger)
        logger.log('Environment Variables', ENV.to_hash)
      end

      def self.component_detections(components)
        components.map { |component| component.detect }.compact
      end

      def self.components(logger)
        expanded_path = File.expand_path(COMPONENTS_CONFIG, File.dirname(__FILE__))
        components = YAML.load_file(expanded_path)

        logger.log(expanded_path, components)

        components
      end

      def self.configuration(app_dir, type, logger)
        name = type.match(/^(?:.*::)?(.*)$/)[1].downcase
        config_file = File.expand_path("../../config/#{name}.yml", File.dirname(__FILE__))

        if File.exists? config_file
          configuration = YAML.load_file(config_file)

          logger.log(config_file, configuration)
        end

        configuration || {}
      end

      def self.configure_context(basic_context, type, logger)
        configured_context = basic_context.clone
        configured_context[:configuration] = Buildpack.configuration(configured_context[:app_dir], type, logger)
        configured_context
      end

      def self.construct_components(components, type, basic_context, logger)
        components[type].map do |component|
          component.constantize.new(Buildpack.configure_context(basic_context, component, logger))
        end
      end

      def self.container_directory
        Pathname.new(File.expand_path('container', File.dirname(__FILE__)))
      end

      def self.framework_directory
        Pathname.new(File.expand_path('framework', File.dirname(__FILE__)))
      end

      def self.jre_directory
        Pathname.new(File.expand_path('jre', File.dirname(__FILE__)))
      end

      def self.lib_directory(app_dir)
        File.join app_dir, LIB_DIRECTORY
      end

      def self.require_component_files
        component_files = jre_directory.children
        component_files.concat framework_directory.children
        component_files.concat container_directory.children

        component_files.each do |file|
          require file.relative_path_from(root_directory) unless file.directory?
        end
      end

      def self.root_directory
        Pathname.new(File.expand_path('..', File.dirname(__FILE__)))
      end

      def container
        @containers.find { |container| container.detect }
      end

      def frameworks
        @frameworks.select { |framework| framework.detect }
      end

      def jre
        @jres.find { |jre| jre.detect }
      end

  end

end
