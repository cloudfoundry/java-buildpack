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
require 'java_buildpack/util/play/factory'
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

    def supports?
      candidate = false

      play_app = JavaBuildpack::Util::Play::Factory.create @application
      candidate = uses_jpa?(play_app) || play20?(play_app.version) if play_app

      candidate
    end

    private

    def jar_name
      "#{@parsable_component_name}-#{@version}.jar"
    end

    def play20?(version)
      version.start_with? '2.0'
    end

    def uses_jpa?(play_app)
      play_app.has_jar? /.*play-java-jpa.*\.jar/
    end

  end

end
