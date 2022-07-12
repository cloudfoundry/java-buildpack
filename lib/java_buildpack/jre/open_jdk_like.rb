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

require 'java_buildpack/component/modular_component'
require 'java_buildpack/jre'
require 'java_buildpack/jre/jvmkill_agent'
require 'java_buildpack/jre/open_jdk_like_jre'
require 'java_buildpack/jre/open_jdk_like_memory_calculator'
require 'java_buildpack/jre/open_jdk_like_security_providers'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK-like JRE.
    class OpenJDKLike < JavaBuildpack::Component::ModularComponent

      protected

      # (see JavaBuildpack::Component::ModularComponent#command)
      def command
        @sub_components.find { |candidate| candidate.is_a? OpenJDKLikeMemoryCalculator }.memory_calculation_command
      end

      # (see JavaBuildpack::Component::ModularComponent#sub_components)
      def sub_components(context)
        [
          OpenJDKLikeJre.new(sub_configuration_context(context, 'jre')
                               .merge(component_name: self.class.to_s.space_case)),
          OpenJDKLikeSecurityProviders.new(context)
        ]
      end

      # (see JavaBuildpack::Component::ModularComponent#supports?)
      def supports?
        true
      end

    end

  end
end
