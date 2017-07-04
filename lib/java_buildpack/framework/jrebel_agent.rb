# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'JRebel Agent'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_agentpath(@droplet.sandbox + ('lib/' + lib_name))
          .add_system_property('rebel.remoting_plugin', true)
          .add_system_property('rebel.cloud.platform', 'cloudfoundry/java-buildpack')
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        enabled? && (
            jrebel_configured?(@application.root) ||
            jrebel_configured?(@application.root + 'WEB-INF/classes') ||
            jars_with_jrebel_configured?(@application.root))
      end

      private

      def jrebel_configured?(root_path)
        (root_path + 'rebel-remote.xml').exist?
      end

      def jars_with_jrebel_configured?(root_path)
        (root_path + '**/*.jar').glob.any? { |jar| !`unzip -l "#{jar}" | grep "rebel-remote\\.xml$"`.strip.empty? }
      end

      def lib_name
        architecture == 'x86_64' || architecture == 'i686' ? 'libjrebel64.so' : 'libjrebel32.so'
      end

      def architecture
        `uname -m`.strip
      end

      def enabled?
        @configuration['enabled'].nil? || @configuration['enabled']
      end

    end

  end
end
