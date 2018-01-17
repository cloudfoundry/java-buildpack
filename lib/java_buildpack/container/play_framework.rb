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
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/play/factory'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Play applications.
    class PlayFramework < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @delegate = JavaBuildpack::Util::Play::Factory.create @droplet
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @delegate ? id(@delegate.version) : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @delegate&.compile
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @delegate&.release
      end

      private

      def id(version)
        "#{PlayFramework.to_s.dash_case}=#{version}"
      end

    end

  end
end
