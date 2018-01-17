# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

require 'java_buildpack/component/base_component'
require 'java_buildpack/container'

module JavaBuildpack
  module Container

    # Encapsulates the functionality for contributing really long detect tags.
    class LongDetectTags < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        [[].fill(0, 300) { 'A' }.join]
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile; end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

    end

  end
end
