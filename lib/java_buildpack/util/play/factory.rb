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

require 'java_buildpack/util/play'
require 'java_buildpack/util/play/post22_dist'
require 'java_buildpack/util/play/post22_staged'
require 'java_buildpack/util/play/pre22_dist'
require 'java_buildpack/util/play/pre22_staged'

module JavaBuildpack
  module Util
    module Play

      # A factory for creating a version-appropriate Play Framework application delegate
      class Factory

        private_class_method :new

        class << self

          # Creates a Play Framework application based on the given application directory.
          #
          # @param [JavaBuildpack::Component::Droplet] droplet the droplet
          # @return [JavaBuildpack::Util::Play::Base] the Plat Framework application delegate
          def create(droplet)
            candidates = [
              Post22Dist.new(droplet),
              Post22Staged.new(droplet),
              Pre22Dist.new(droplet),
              Pre22Staged.new(droplet)
            ].select(&:supports?)

            raise "Play Framework application version cannot be determined: #{candidates}" if candidates.size > 1
            candidates.empty? ? nil : candidates.first
          end

        end

      end

    end
  end
end
