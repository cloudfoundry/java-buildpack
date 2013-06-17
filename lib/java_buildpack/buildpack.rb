# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

require 'java_buildpack'
require 'java_buildpack/system_properties'
require 'java_buildpack/util/constantize'
require 'pathname'
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
      Buildpack.require_component_files
      components = Buildpack.components

      java_home = String.new
      java_opts = Array.new

      @jres = components['jres'].map do |jre|
        jre.constantize.new({
          :app_dir => app_dir,
          :java_home => java_home,
          :java_opts => java_opts,
          :configuration => Buildpack.configuration(app_dir, jre)
        })
      end

      @frameworks = components['frameworks'].map do |framework|
        framework.constantize.new({
          :app_dir => app_dir,
          :java_home => java_home,
          :java_opts => java_opts,
          :configuration => Buildpack.configuration(app_dir, framework)
        })
      end

      @containers = components['containers'].map do |container|
        container.constantize.new({
          :app_dir => app_dir,
          :java_home => java_home,
          :java_opts => java_opts,
          :configuration => Buildpack.configuration(app_dir, container)
        })
      end

    end

    # Iterates over all of the components to detect if this buildpack can be used to run an application
    #
    # @return [Array<String>] An array of strings that identify the components and versions that will be used to run
    #                         this application.  If no container can run the application, the array will be empty
    #                         (+[]+).
    def detect
      jre_detections = @jres.map { |jre| jre.detect }.compact
      raise "Application can be run useing more than one JRE: #{jre_detections.join(', ')}" if jre_detections.size > 1

      framework_detections = @frameworks.map { |framework| framework.detect }.compact

      container_detections = @containers.map { |container| container.detect }.compact
      raise "Application can be run by more than one container: #{container_detections.join(', ')}" if container_detections.size > 1

      container_detections.empty? ? [] : jre_detections.concat(framework_detections).concat(container_detections).flatten.compact
    end

    # Transforms the application directory such that the JRE, container, and frameworks can run the application
    #
    # @return [void]
    def compile
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

      {
          'addons' => [],
          'config_vars' => {},
          'default_process_types' => {
              'web' => command
          }
      }.to_yaml
    end

    private

    COMPONENTS_CONFIG = '../../config/components.yml'.freeze

    def self.components
      YAML.load_file(File.expand_path(COMPONENTS_CONFIG, File.dirname(__FILE__)))
    end

    def self.configuration(app_dir, type)
      configuration = {}

      name = type.match(/^(?:.*::)?(.*)$/)[1].downcase
      config_file = File.expand_path("../../config/#{name}.yml", File.dirname(__FILE__))
      configuration.merge!(YAML.load_file(config_file)) if File.exists? config_file

      configuration.merge!(SystemProperties.new(app_dir))

      configuration
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

    def self.require_component_files
      component_files = jre_directory.children()
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
      @containers.detect { |container| container.detect }
    end

    def frameworks
      @frameworks.select { |framework| framework.detect }
    end

    def jre
      @jres.detect { |jre| jre.detect }
    end

  end

end
