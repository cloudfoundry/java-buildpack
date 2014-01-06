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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/container'
require 'java_buildpack/util/class_file_utils'
require 'java_buildpack/util/groovy_utils'
require 'java_buildpack/util/qualify_path'
require 'pathname'
require 'set'
require 'tmpdir'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running non-compiled Groovy
  # applications.
  class Groovy < JavaBuildpack::Component::VersionedDependencyComponent
    include JavaBuildpack::Util

    def initialize(context)
      super(context) { |candidate_version| candidate_version.check_size(3) }
    end

    def compile
      download_zip
    end

    def release
      [
          @droplet.java_home.as_env_var,
          @droplet.java_opts.as_env_var,
          qualify_path(@droplet.sandbox + 'bin/groovy', @droplet.root),
          @droplet.additional_libraries.as_classpath,
          relative_main_groovy,
          relative_other_groovy
      ].compact.join(' ')
    end

    protected

    def supports?
      JavaBuildpack::Util::ClassFileUtils.class_files(@application).empty? && main_groovy
    end

    private

    def main_groovy
      candidates = JavaBuildpack::Util::GroovyUtils.groovy_files(@application)

      candidate = []
      candidate << main_method(candidates)
      candidate << non_pogo(candidates)
      candidate << shebang(candidates)

      candidate = Set.new(candidate.flatten.compact).to_a
      candidate.size == 1 ? candidate[0] : nil
    end

    def other_groovy
      other_groovy = JavaBuildpack::Util::GroovyUtils.groovy_files(@application)
      other_groovy.delete(main_groovy)
      other_groovy
    end

    def main_method(candidates)
      select(candidates) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file }
    end

    def non_pogo(candidates)
      reject(candidates) { |file| JavaBuildpack::Util::GroovyUtils.pogo? file }
    end

    def relative_main_groovy
      main_groovy.relative_path_from(@application.root)
    end

    def relative_other_groovy
      other_groovy.map { |gf| gf.relative_path_from(@application.root) }
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
      candidate.open('r', external_encoding: 'UTF-8', &block)
    end

  end

end
