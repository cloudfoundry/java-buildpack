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

  # Base class for inspection and modification of Play applications up to and including Play 2.1.x.
  class PlayAppPre22 < BasePlayApp
    include JavaBuildpack::Util::Shell

    def initialize(app_dir)
      super(app_dir)
    end

    protected

    # Symbolically links to the given JARs from the classpath directory.
    #
    # @param [Array<String>] libs the JAR paths
    def link_libs_from_classpath_dir(libs)
      JavaBuildpack::Container::ContainerUtils.relative_paths(play_root, libs).each do |lib|
        shell "ln -nsf ../#{lib} #{self.class.classpath_directory(play_root)}"
      end
    end

    private

    START_SCRIPT = 'start'.freeze

    def self.start_script(root)
      Dir[File.join(root, START_SCRIPT)].first
    end

  end

end
