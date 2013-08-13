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
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/groovy_utils'
require 'pathname'
require 'set'
require 'tmpdir'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running non-compiled Groovy
  # applications.
  class Groovy

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
      @version, @uri = Groovy.find_groovy(@app_dir, @configuration)
    end

    # Detects whether this application is Groovy application.
    #
    # @return [String] returns +groovy-<version>+ if and only if:
    #                  * a single +.groovy+ file exists
    #                  * multiple +.groovy+ files exist and one of them is named +main.groovy+ or +Main.groovy+
    #                  * multiple +.groovy+ files exist and one of them has a +main()+ method
    #                  * multiple +.groovy+ files exist and one of them is not a POGO
    #                  * multiple +.groovy+ files exist and one of them has a #! declaration
    #                  otherwise it returns +nil+.
    def detect
      @version ? id(@version) : nil
    end

    # Downloads and unpacks a Groovy distribution
    #
    # @return [void]
    def compile
      download_start_time = Time.now
      print "-----> Downloading Groovy #{@version} from #{@uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@uri) do |file|  # TODO: Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        expand(file, @configuration)
      end
    end

    # Creates the command to run the Java +main()+ application.
    #
    # @return [String] the command to run the application.
    def release
      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      groovy_string = ContainerUtils.space(File.join GROOVY_HOME, 'bin', 'groovy')
      classpath_string = ContainerUtils.space(classpath(@app_dir, @lib_directory))
      main_groovy_string = ContainerUtils.space(Groovy.main_groovy @app_dir)
      other_groovy_string = ContainerUtils.space(other_groovy @app_dir)

      "#{java_home_string}#{java_opts_string}#{groovy_string}#{classpath_string}#{main_groovy_string}#{other_groovy_string}"
    end

    private

      GROOVY_FILE_PATTERN = '**/*.groovy'.freeze

      GROOVY_HOME = '.groovy'.freeze

      def classpath(app_dir, lib_directory)
        classpath = ContainerUtils.libs(app_dir, lib_directory)

        classpath.any? ? "-cp #{classpath.join(':')}" : ''
      end

      def expand(file, configuration)
        expand_start_time = Time.now
        print "       Expanding Groovy to #{GROOVY_HOME} "

        Dir.mktmpdir do |root|
          system "rm -rf #{groovy_home}"
          system "mkdir -p #{File.dirname groovy_home}"
          system "unzip -qq #{file.path} -d #{root} 2>&1"
          system "mv #{root}/$(ls #{root}) #{groovy_home}"
        end

        puts "(#{(Time.now - expand_start_time).duration})"
      end

      def self.find_groovy(app_dir, configuration)
        if main_groovy app_dir
          version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration) do |candidate_version|
            fail "Malformed Groovy version #{candidate_version}: too many version components" if candidate_version[3]
          end
        else
          version = nil
          uri = nil
        end

        return version, uri # rubocop:disable RedundantReturn
      rescue => e
        raise RuntimeError, "Groovy container error: #{e.message}", e.backtrace
      end

      def self.groovy_files(root)
        root_directory = Pathname.new(root)
        Dir[File.join root, GROOVY_FILE_PATTERN].reject { |file| File.directory? file } .map { |file| Pathname.new(file).relative_path_from(root_directory).to_s }
      end

      def groovy_home
        File.join @app_dir, GROOVY_HOME
      end

      def id(version)
        "groovy-#{version}"
      end

      def self.main_groovy(app_dir)
        candidates = groovy_files(app_dir)

        candidate = []
        candidate << main_method(app_dir, candidates)
        candidate << non_pogo(app_dir, candidates)
        candidate << shebang(app_dir, candidates)

        candidate = Set.new(candidate.flatten.compact).to_a
        candidate.size == 1 ? candidate[0] : nil
      end

      def other_groovy(app_dir)
        other_groovy = Groovy.groovy_files(app_dir)
        other_groovy.delete(Groovy.main_groovy(app_dir))
        other_groovy.join(' ')
      end

      def self.main_method(app_dir, candidates)
        select(app_dir, candidates) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file }
      end

      def self.non_pogo(app_dir, candidates)
        reject(app_dir, candidates) { |file| JavaBuildpack::Util::GroovyUtils.pogo? file }
      end

      def self.shebang(app_dir, candidates)
        select(app_dir, candidates) { |file| JavaBuildpack::Util::GroovyUtils.shebang? file }
      end

      def self.reject(app_dir, candidates, &block)
        candidates.reject { |candidate| open(app_dir, candidate, &block) }
      end

      def self.select(app_dir, candidates, &block)
        candidates.select { |candidate| open(app_dir, candidate, &block) }
      end

      def self.open(app_dir, candidate, &block)
        File.open(File.join(app_dir, candidate), 'r', external_encoding: 'UTF-8', &block)
      end

  end

end
