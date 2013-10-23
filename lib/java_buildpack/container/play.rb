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

require 'java_buildpack/base_component'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/util/play_app_factory'
require 'pathname'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Play applications.
  class Play < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Play Framework', context)

      @play_app = JavaBuildpack::Util::PlayAppFactory.create @app_dir
    end

    def detect
      if @play_app
        version = @play_app.version
        version ? id(version) : nil
      else
        nil
      end
    end

    def compile
      @play_app.set_executable
      @play_app.add_libs_to_classpath additional_libraries
      @play_app.replace_bootstrap BOOTSTRAP_CLASS_NAME
    end

    def release
      java_opts = @java_opts.clone
      java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      path_string = "PATH=#{File.join @java_home, 'bin'}:$PATH"
      java_home_string = ContainerUtils.space("JAVA_HOME=#{@java_home}")
      start_script_string = ContainerUtils.space(@play_app.start_script_relative)
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@play_app.decorate_java_opts java_opts))

      "#{path_string}#{java_home_string}#{start_script_string}#{java_opts_string}"
    end

    private

    BOOTSTRAP_CLASS_NAME = 'org.cloudfoundry.reconfiguration.play.Bootstrap'.freeze

    KEY_HTTP_PORT = 'http.port'.freeze

    def id(version)
      "#{@parsable_component_name}=#{version}"
    end

  end

end
