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
require 'java_buildpack/util/properties'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Java applications whose start command is embedded in a Procfile
  # This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle of Java
  # +main()+ applications.
  class Procfile < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Java Procfile', context)
    end

    def detect
      find_file("Procfile") ? id : nil
    end

    def compile 
      gem_home = "#{@lib_directory}/.gem"
      puts "-----> Fetching foreman into #{gem_home}"
      system "GEM_HOME=#{gem_home} gem install foreman --no-ri"
    end

    def release
      java_bin = File.join @java_home, 'bin'
      relative_gem_home= "#{relative_lib_directory}/.gem"
      java_opts_string = "JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\""
      gem_home_string = "GEM_HOME=#{relative_gem_home}"
      path_string = "PATH=#{java_bin}:$PATH"
      foreman_string = "#{relative_gem_home}/bin/foreman start"

      "#{path_string} #{gem_home_string} #{java_opts_string} #{foreman_string}"
    end

    private

    ARGUMENTS_PROPERTY = 'arguments'.freeze

    def arguments
      @configuration[ARGUMENTS_PROPERTY]
    end

    def id
      'java-procfile'
    end

    def find_file(filename)
      filepath = File.join(@app_dir, filename)
      filepath = File.exists?(filepath) ? filepath : nil
      JavaBuildpack::Util::Properties.new(filepath)
    end

    def relative_lib_directory
      @lib_directory.sub! "#{@app_dir}/", './'
    end

  end

end
