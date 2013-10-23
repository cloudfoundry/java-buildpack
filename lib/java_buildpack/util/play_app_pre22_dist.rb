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
require 'java_buildpack/util/play_app_pre22'

module JavaBuildpack::Util

  # Encapsulate inspection and modification of Play dist applications up to and including Play 2.1.x.
  class PlayAppPre22Dist < PlayAppPre22

    def initialize(app_dir)
      super(app_dir)
      @play_root, @version = self.class.root_and_version(app_dir)
    end

    def add_libs_to_classpath(libs)
      # In Play 2.1.x dist applications, the start script contains a list of JARs which form the classpath. To add
      # libraries to the classpath, the script is edited to extend the list of JARs.
      #
      # For Play Play 2.0.x dist applications, the start script builds a classpath dynamically
      # from the set of JARs in the +lib+ directory. To add libraries to the classpath,
      # the JARs are symbolically linked into the +lib+ directory.
      add_libs_to_dist_classpath(libs)
    end

    private

    def add_libs_to_dist_classpath(libs)
      # Dist applications either list JARs in a classpath variable (e.g. in Play 2.1.3) or add all the JARs in the lib
      # directory to the classpath using a -cp parameter (e.g. in Play 2.0).
      script_dir_relative_path = Pathname.new(app_dir).relative_path_from(Pathname.new(@play_root)).to_s

      additional_classpath = JavaBuildpack::Container::ContainerUtils.relative_paths(app_dir, libs).map do |lib|
        "$scriptdir/#{script_dir_relative_path}/#{lib}"
      end

      result = update_file start_script, /^classpath=\"(.*)\"$/, "classpath=\"#{additional_classpath.join(':')}:\\1\""
      unless result
        # No classpath variable was found, so add symbolic links to the lib directory.
        link_libs_from_classpath_dir(libs)
      end
    end

  end

end
