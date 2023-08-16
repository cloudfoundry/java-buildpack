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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/spring_boot_utils'

module JavaBuildpack
  module Framework

    # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Spring
    # applications.
    class JavaCfEnv < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      def initialize(context)
        @spring_boot_utils = JavaBuildpack::Util::SpringBootUtils.new
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
        @droplet.environment_variables.add_environment_variable 'SPRING_PROFILES_INCLUDE', 'cloud'
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['enabled'] &&  spring_boot_3? && !java_cfenv?
      end

      private

      def spring_boot_3?
        @spring_boot_utils.is?(@application) && Gem::Version.new((@spring_boot_utils.version @application)).release >=
          Gem::Version.new('3.0.0')
      end

      def java_cfenv?
        (@droplet.root + '**/*java-cfenv*.jar').glob.any?
      end

    end
  end
end
