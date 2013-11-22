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

require 'fileutils'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/groovy_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running Spring Boot CLI
  # applications.
  class SpringBootCli < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('Spring Boot CLI', context)
    end

    def compile
      download { |file| expand file }
      link_classpath_jars
    end

    def release
      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      spring_boot_script = ContainerUtils.space(File.join SPRING_BOOT_CLI_HOME, 'bin', 'spring')
      groovy_string = ContainerUtils.space(groovy)

      "#{java_home_string}#{java_opts_string}#{spring_boot_script} run --local#{groovy_string} -- --server.port=$PORT"
    end

    protected

    def supports?
      gf = JavaBuildpack::Util::GroovyUtils.groovy_files(@app_dir)
      gf.length > 0 && all_pogo(gf) && no_main_method(gf) && !has_web_inf
    end

    private

    SPRING_BOOT_CLI_HOME = '.spring-boot-cli'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding Spring Boot CLI to #{SPRING_BOOT_CLI_HOME} "

      FileUtils.rm_rf spring_boot_cli_home
      FileUtils.mkdir_p spring_boot_cli_home
      shell "tar xzf #{file.path} -C #{spring_boot_cli_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def groovy
      other_groovy = JavaBuildpack::Util::GroovyUtils.groovy_files(@app_dir)
      other_groovy.join(' ')
    end

    def link_classpath_jars
      ContainerUtils.libs(@app_dir, @lib_directory).each do |lib|
        shell "ln -nsf ../../#{lib} #{spring_lib_dir}"
      end
    end

    def spring_boot_cli_home
      File.join @app_dir, SPRING_BOOT_CLI_HOME
    end

    def spring_lib_dir
      File.join(spring_boot_cli_home, 'lib')
    end

    def no_main_method(groovy_files)
      none?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file } # note that this will scan comments
    end

    def has_web_inf
      File.exist?(File.join(@app_dir, 'WEB-INF'))
    end

    def all_pogo(groovy_files)
      all?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.pogo? file } # note that this will scan comments
    end

    def all?(groovy_files, &block)
      groovy_files.all? { |file| open(file, &block) }
    end

    def none?(groovy_files, &block)
      groovy_files.none? { |file| open(file, &block) }
    end

    def open(file, &block)
      File.open(File.join(@app_dir, file), 'r', external_encoding: 'UTF-8', &block)
    end

  end

end
