# Encoding: utf-8
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

require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/groovy_utils'
require 'fileutils'
require 'pathname'
require 'set'
require 'tmpdir'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running Spring Boot CLI
  # applications.
  class SpringBootCli

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
      @version, @uri = SpringBootCli.find_spring_boot_cli(@app_dir, @configuration)
    end

    # Detects whether this application is a Spring Boot CLI application.
    #
    # @return [String] returns +spring-boot-cli-<version>+ if and only if:
    #                  * The application has one or more +.groovy+ files in the root directory, and
    #                  * All the application's +.groovy+ files in the root directory are POGOs (a POGO contains one or more classes), and
    #                  * None of the application's +.groovy+ files in the root directory contain a +main+ method, and
    #                  * The application does not have a +WEB-INF+ subdirectory of its root directory
    #                  otherwise it returns +nil+.
    def detect
      @version ? id(@version) : nil
    end

    # Downloads and unpacks a Spring Boot CLI distribution and copies classpath JARs to its +lib+ directory.
    #
    # @return [void]
    def compile
      download_start_time = Time.now
      print "-----> Downloading Spring Boot CLI #{@version} from #{@uri} "

      JavaBuildpack::Util::ApplicationCache.new.get(@uri) do |file| # TODO: Use global cache #50175265
        puts "(#{(Time.now - download_start_time).duration})"
        expand(file, @configuration)
      end
      link_classpath_jars
    end

    # Creates the command to run the Java +main()+ application.
    #
    # @return [String] the command to run the application.
    def release
      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      spring_boot_script = ContainerUtils.space(File.join SPRING_BOOT_CLI_HOME, 'bin', 'spring')

      "#{java_home_string}#{java_opts_string}#{spring_boot_script} run --local *.groovy -- --server.port=$PORT"
    end

    private

    GROOVY_FILE_PATTERN = '*.groovy'.freeze

    SPRING_BOOT_CLI_HOME = '.spring-boot-cli'.freeze

    def link_classpath_jars
      ContainerUtils.libs(@app_dir, @lib_directory).each do |lib|
        system "ln -nsf ../../#{lib} #{spring_lib_dir}"
      end
    end

    def spring_lib_dir
      File.join(spring_boot_cli_home, 'lib')
    end

    def expand(file, configuration)
      expand_start_time = Time.now
      print "       Expanding Spring Boot CLI to #{SPRING_BOOT_CLI_HOME} "

      Dir.mktmpdir do |tmpdir_root|
        system "rm -rf #{spring_boot_cli_home}"
        system "mkdir -p #{spring_boot_cli_home}"
        system "tar xzf #{file.path} -C #{spring_boot_cli_home} --strip 1 2>&1"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def self.find_spring_boot_cli(app_dir, configuration)
      if spring_boot_cli app_dir
        version, uri = JavaBuildpack::Repository::ConfiguredItem.find_item(configuration)
      else
        version = nil
        uri = nil
      end

      return version, uri # rubocop:disable RedundantReturn
    rescue => e
      raise RuntimeError, "Spring Boot CLI container error: #{e.message}", e.backtrace
    end

    def self.groovy_files(root)
      root_directory = Pathname.new(root)
      Dir[File.join root, GROOVY_FILE_PATTERN].reject { |file| File.directory? file }.map { |file| Pathname.new(file).relative_path_from(root_directory).to_s }
    end

    def spring_boot_cli_home
      File.join @app_dir, SPRING_BOOT_CLI_HOME
    end

    def spring_boot_cli_invocation
      " -jar #{}"
    end

    def id(version)
      "spring-boot-cli-#{version}"
    end

    # Determine whether or not the Spring Boot CLI container recognises the application.
    def self.spring_boot_cli(app_dir)
      gf = groovy_files(app_dir)
      gf.length > 0 && all_pogo(app_dir, gf) && no_main_method(app_dir, gf) && !has_web_inf(app_dir)
    end

    def self.no_main_method(app_dir, groovy_files)
      none?(app_dir, groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file } # note that this will scan comments
    end

    def self.has_web_inf(app_dir)
      File.exist?(File.join(app_dir, 'WEB-INF'))
    end

    def self.all_pogo(app_dir, groovy_files)
      all?(app_dir, groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.pogo? file } # note that this will scan comments
    end

    def self.all?(app_dir, groovy_files, &block)
      groovy_files.all? { |file| open(app_dir, file, &block) }
    end

    def self.none?(app_dir, groovy_files, &block)
      groovy_files.none? { |file| open(app_dir, file, &block) }
    end

    def self.open(app_dir, file, &block)
      File.open(File.join(app_dir, file), 'r', external_encoding: 'UTF-8', &block)
    end

  end

end
