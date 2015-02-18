# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch JRebel support.
    class JrebelAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip false
        FileUtils.mv(download_location + 'jrebel.jar', @droplet.sandbox + jar_name)
        FileUtils.remove_dir(download_location, true)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
          .add_javaagent(@droplet.sandbox + jar_name)
          .add_bootclasspath_p(@droplet.sandbox + jar_name)
          .add_system_property('rebel.remoting_plugin', true)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        jrebel_configured?(@application.root) || jrebel_configured?(@application.root + 'WEB-INF/classes')
      end

      private

      def jrebel_configured?(root_path)
        (root_path + 'rebel.xml').exist? && (root_path + 'rebel-remote.xml').exist?
      end

      def download_location
        @droplet.sandbox + 'jrebel'
      end

    end

  end
end
