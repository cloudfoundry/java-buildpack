# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
    class CodeInsightAgent < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context, &version_validator)
        super(context, &version_validator)
        @component_name = 'CodeInsight-Java'
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_javaagent(agent_jar)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        codeinsight_configured?(@droplet.sandbox + 'CodeInsight-Java.jar') &&
        codeinsight_configured?(@droplet.sandbox + 'CodeInsight-Java.xml')
      end

      private

      def codeinsight_configured?(root_path)
        (root_path).exist?
      end

      def agent_jar
        @droplet.sandbox + 'CodeInsight-Java.jar'
      end

    end

  end
end
