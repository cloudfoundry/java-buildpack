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
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/groovy_utils'
require 'java_buildpack/versioned_dependency_component'
require 'pathname'
require 'set'
require 'tmpdir'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running non-compiled Groovy
  # applications.
  class Groovy < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('Groovy', context) { |candidate_version| candidate_version.check_size(3) }
    end

    def compile
      download_zip groovy_home
    end

    def release
      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")
      groovy_string = ContainerUtils.space(File.join GROOVY_HOME, 'bin', 'groovy')
      classpath_string = ContainerUtils.space(classpath)
      main_groovy_string = ContainerUtils.space(main_groovy)
      other_groovy_string = ContainerUtils.space(other_groovy)

      "#{java_home_string}#{java_opts_string}#{groovy_string}#{classpath_string}#{main_groovy_string}#{other_groovy_string}"
    end

    protected

    def supports?
      main_groovy
    end

    private

    GROOVY_HOME = '.groovy'.freeze

    def classpath
      classpath = ContainerUtils.libs(@app_dir, @lib_directory)
      classpath.any? ? "-cp #{classpath.join(':')}" : ''
    end

    def groovy_home
      File.join @app_dir, GROOVY_HOME
    end

    def main_groovy
      candidates = JavaBuildpack::Util::GroovyUtils.groovy_files(@app_dir)

      candidate = []
      candidate << main_method(candidates)
      candidate << non_pogo(candidates)
      candidate << shebang(candidates)

      candidate = Set.new(candidate.flatten.compact).to_a
      candidate.size == 1 ? candidate[0] : nil
    end

    def other_groovy
      other_groovy = JavaBuildpack::Util::GroovyUtils.groovy_files(@app_dir)
      other_groovy.delete(main_groovy)
      other_groovy.join(' ')
    end

    def main_method(candidates)
      select(candidates) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file }
    end

    def non_pogo(candidates)
      reject(candidates) { |file| JavaBuildpack::Util::GroovyUtils.pogo? file }
    end

    def shebang(candidates)
      select(candidates) { |file| JavaBuildpack::Util::GroovyUtils.shebang? file }
    end

    def reject(candidates, &block)
      candidates.reject { |candidate| open(candidate, &block) }
    end

    def select(candidates, &block)
      candidates.select { |candidate| open(candidate, &block) }
    end

    def open(candidate, &block)
      File.open(File.join(@app_dir, candidate), 'r', external_encoding: 'UTF-8', &block)
    end

  end

end
