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
      download_tar
      @application.additional_libraries.link_to lib_dir
    end

    def release
      [
          @application.java_home.as_env_var,
          @application.java_opts.as_env_var,
          @application.relative_path_to(home + 'bin/spring'),
          'run',
          '--local',
          JavaBuildpack::Util::GroovyUtils.groovy_files(@application),
          '--',
          '--server.port=$PORT'
      ].compact.join(' ')
    end

    protected

    def supports?
      gf = JavaBuildpack::Util::GroovyUtils.groovy_files(@application)
      gf.length > 0 && all_pogo(gf) && no_main_method(gf) && no_shebang(gf) && !has_web_inf
    end

    private

    def lib_dir
      home + 'lib'
    end

    def no_main_method(groovy_files)
      none?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.main_method? file } # note that this will scan comments
    end

    def no_shebang(groovy_files)
      none?(groovy_files) { |file| JavaBuildpack::Util::GroovyUtils.shebang? file }
    end

    def has_web_inf
      @application.child('WEB-INF').exist?
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
      @application.child(file).open('r', external_encoding: 'UTF-8', &block)
    end

  end

end
