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

require 'java_buildpack/framework'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/play_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Play
  # applications that use JPA. Note that Spring auto-reconfiguration is covered by the SpringAutoReconfiguration
  # framework. The reconfiguration performed here is to override Play application configuration to bind a Play
  # application to cloud resources.
  class PlayJpaPlugin < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('Play JPA Plugin', context)
    end

    def compile
      download_jar jar_name
    end

    def release
    end

    protected

    def id(version)
      "play-jpa-plugin-#{version}"
    end

    def supports?
      candidate = false

      root = JavaBuildpack::Util::PlayUtils.root @app_dir
      candidate = uses_jpa?(root) || play20?(root) if root

      candidate
    end

    private

    PLAY_JPA_PLUGIN_JAR = '*play-java-jpa*.jar'.freeze

    def jar_name
      "#{id @version}.jar"
    end

    def play20?(root)
      JavaBuildpack::Util::PlayUtils.version(root) =~ /2.0.[\d]+/
    end

    def uses_jpa?(root)
      lib = File.join JavaBuildpack::Util::PlayUtils.lib(root), PLAY_JPA_PLUGIN_JAR
      staged = File.join JavaBuildpack::Util::PlayUtils.staged(root), PLAY_JPA_PLUGIN_JAR
      Dir[lib, staged].first
    end

  end

end
