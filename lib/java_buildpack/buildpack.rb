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
require 'java_buildpack/application'
require 'java_buildpack/diagnostics/common'
require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/util/constantize'
require 'java_buildpack/util/shell'
require 'pathname'
require 'time'
require 'yaml'

module JavaBuildpack

  # Encapsulates the detection, compile, and release functionality for Java application
  class Buildpack
    include JavaBuildpack::Util::Shell

    # +Buildpack+ driver method. Creates a logger and yields a new instance of +Buildpack+
    # to the given block catching any exceptions and logging diagnostics. As part of initialisation,
    # all of the files located in the following directories are +require+d:
    # * +lib/java_buildpack/container+
    # * +lib/java_buildpack/jre+
    # * +lib/java_buildpack/framework+
    #
    # @param [String] app_dir the path of the application directory
    # @param [String] message an error message with an insert for the reason for failure
    # @return [Object] the return value from the given block
    def self.drive_buildpack_with_logger(app_dir, message)
      logger = JavaBuildpack::Diagnostics::LoggerFactory.create_logger app_dir
      begin
        yield new(app_dir)
      rescue => e
        logger.error(message % e.inspect)
        logger.debug("Exception #{e.inspect} backtrace:\n#{e.backtrace.join("\n")}")
        abort e.message
      end
    end

    # Iterates over all of the components to detect if this buildpack can be used to run an application
    #
    # @return [Array<String>] An array of strings that identify the components and versions that will be used to run
    #                         this application.  If no container can run the application, the array will be empty
    #                         (+[]+).
    def detect
      jre_detections = jre_detect_tags

      framework_detections = Buildpack.component_detections @frameworks

      container_detections = container_detect_tags

      tags = container_detections.empty? ? [] : jre_detections.concat(framework_detections).concat(container_detections).flatten.compact
      @logger.debug { "Detection Tags: #{tags}" }
      tags
    end

    # Transforms the application directory such that the JRE, container, and frameworks can run the application
    #
    # @return [void]
    def compile
      the_container = container # diagnose detect failure early
      FileUtils.mkdir_p @lib_directory

      jre.compile
      frameworks.each { |framework| framework.compile }
      the_container.compile
    end

    # Generates the payload required to run the application.  The payload format is defined by the
    # {Heroku Buildpack API}[https://devcenter.heroku.com/articles/buildpack-api#buildpack-api].
    #
    # @return [String] The payload required to run the application.
    def release
      the_container = container # diagnose detect failure early
      jre.release
      frameworks.each { |framework| framework.release }
      command = the_container.release

      payload = {
          'addons' => [],
          'config_vars' => {},
          'default_process_types' => {
              'web' => command
          }
      }.to_yaml

      @logger.debug { "Release Payload #{payload}" }

      payload
    end

    # Returns the configuration hash of the given type or the empty hash if the type has no such configuration.
    #
    # @param [String] type the class name of the type whose configuration is required
    # @param [Logger] logger a +Logger+
    # @return [Hash] the type's configuration
    def self.configuration(type, logger)
      name = type.match(/^(?:.*::)?(.*)$/)[1].downcase
      config_file = File.expand_path("../../config/#{name}.yml", File.dirname(__FILE__))

      if File.exists? config_file
        configuration = YAML.load_file(config_file)

        logger.debug { "#{config_file} contents: #{configuration}" }
      end

      configuration || {}
    end

    private_class_method :new

    private

    COMPONENTS_CONFIG = '../../config/components.yml'.freeze

    LIB_DIRECTORY = '.lib'

    # Instances should only be constructed by this class.
    def initialize(app_dir)
      application = Application.new app_dir

      @logger = JavaBuildpack::Diagnostics::LoggerFactory.get_logger
      Buildpack.log_git_data @logger
      Buildpack.dump_environment_variables @logger
      Buildpack.require_component_files
      components = Buildpack.components @logger

      java_home = ''
      java_opts = []
      @lib_directory = Buildpack.lib_directory app_dir
      environment = ENV.to_hash
      vcap_application = environment.delete 'VCAP_APPLICATION'
      vcap_services = environment.delete 'VCAP_SERVICES'

      basic_context = {
          app_dir: app_dir,
          application: application,
          environment: environment,
          java_home: java_home,
          java_opts: java_opts,
          lib_directory: @lib_directory,
          vcap_application: vcap_application ? YAML.load(vcap_application) : {},
          vcap_services: vcap_services ? YAML.load(vcap_services) : {}
      }

      @jres = Buildpack.construct_components(components, 'jres', basic_context, @logger)
      @frameworks = Buildpack.construct_components(components, 'frameworks', basic_context, @logger)
      @containers = Buildpack.construct_components(components, 'containers', basic_context, @logger)
    end

    def self.dump_environment_variables(logger)
      logger.debug { "Environment Variables: #{ENV.to_hash}" }
    end

    def self.component_detections(components)
      components.map { |component| component.detect }.compact
    end

    def self.components(logger)
      expanded_path = File.expand_path(COMPONENTS_CONFIG, File.dirname(__FILE__))
      components = YAML.load_file(expanded_path)

      logger.debug { "#{expanded_path} contents: #{components}" }

      components
    end

    def self.configure_context(basic_context, type, logger)
      configured_context = basic_context.clone
      configured_context[:configuration] = Buildpack.configuration(type, logger)
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

    def self.git_dir
      File.expand_path('../../.git', File.dirname(__FILE__))
    end

    def self.jre_directory
      Pathname.new(File.expand_path('jre', File.dirname(__FILE__)))
    end

    def self.log_git_data(logger)
      # Log information about the buildpack's git repository to enable stale forks to be spotted.
      # Call the debug method passing a parameter rather than a block so that, should the git command
      # become inaccessible to the buildpack at some point in the future, we find out before someone
      # happens to switch on debug logging.
      if system("git --git-dir=#{git_dir} status 2>/dev/null 1>/dev/null")
        logger.debug("git remotes: #{`git --git-dir=#{git_dir} remote -v`}")
        logger.debug("git HEAD commit: #{`git --git-dir=#{git_dir} log HEAD^!`}")
      else
        logger.debug('Buildpack is not stored in a git repository')
      end
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
      the_detecting_component('container', @containers)
    end

    def container_detect_tags
      detecting_component_tags('container', @containers)
    end

    def diagnose_overlapping_components(component_type, components)
      fail "Application can be run by more than one #{component_type}: #{component_names components}"
    end

    def component_names(components)
      components.map { |component| component.component_name }.join(', ')
    end

    def frameworks
      @frameworks.select { |framework| framework.detect }
    end

    def jre
      the_detecting_component('JRE', @jres)
    end

    def jre_detect_tags
      detecting_component_tags('JRE', @jres)
    end

    def detecting_component_tags(component_type, components)
      component_detections = Buildpack.component_detections components
      diagnose_overlapping_components(component_type, components) if component_detections.size > 1
      component_detections
    end

    def the_detecting_component(component_type, components)
      components = components.select { |component| component.detect }
      diagnose_overlapping_components(component_type, components) if components.size > 1
      fail "No #{component_type} can run the application" if components.empty?
      components[0]
    end

  end

end
