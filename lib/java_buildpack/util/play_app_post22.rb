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

require 'java_buildpack/container/container_utils'
require 'java_buildpack/util'
require 'java_buildpack/util/base_play_app'
require 'java_buildpack/util/shell'

module JavaBuildpack::Util

  # Encapsulate inspection and modification of Play applications from Play 2.2.0 onwards.
  class PlayAppPost22 < BasePlayApp

    def initialize(app_dir)
      super(app_dir)
      @play_root, @version = self.class.root_and_version(app_dir)
    end

    def add_libs_to_classpath(libs)
      script_dir_relative_path = Pathname.new(app_dir).relative_path_from(Pathname.new(File.join(@play_root, 'bin'))).to_s

      additional_classpath = JavaBuildpack::Container::ContainerUtils.relative_paths(app_dir, libs).map do |lib|
        "$app_home/#{script_dir_relative_path}/#{lib}"
      end

      update_file start_script, /^declare -r app_classpath=\"(.*)\"$/, "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
    end

    def decorate_java_opts(java_opts)
      decorated_java_opts = []
      java_opts.each { |java_opt| decorated_java_opts << "-J#{java_opt}" }
      decorated_java_opts
    end

    private

    def self.start_script(app_dir)
      scripts = start_scripts app_dir
      if scripts.size == 1
        scripts[0]
      else
        scripts.find do |script|
          File.exists?("#{script}.bat")
        end
      end
    end

    def self.start_scripts(app_dir)
      Dir[File.join(app_dir, 'bin', '*')]
    end

  end

end
