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

  # Encapsulate inspection and modification of Play staged applications up to and including Play 2.1.x.
  class PlayAppPre22Staged < PlayAppPre22

    def initialize(app_dir)
      super(app_dir)
      @play_root, @version = self.class.root_and_version(app_dir)
    end

    def add_libs_to_classpath(libs)
      # For Play 2.0 and 2.1.x staged applications, the start script builds a classpath dynamically
      # from the set of JARs in the +staged+ directory. To add libraries to the classpath,
      # the JARs are symbolically linked into the +staged+ directory.
      link_libs_from_classpath_dir(libs)
    end

    private

    def self.classpath_directory(root)
      File.join root, 'staged'
    end

  end

end
