# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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
require 'java_buildpack/util/play/post22'
require 'java_buildpack/util/play/pre22_dist'
require 'java_buildpack/util/play/pre22_staged'

module JavaBuildpack::Util::Play

  # A factory for creating a version-appropriate play application delegate
  class Factory

    # Creates a Play application based on the given application directory.
    #
    # @param [JavaBuildpack::Application::Application] application the application
    # @return [JavaBuildpack::Util::Play::Base] the play application delegate
    def self.create(application)
      candidates = [
          Post22.new(application),
          Pre22Dist.new(application),
          Pre22Staged.new(application)
      ].select { |candidate| candidate.supports? }

      fail "Play application version cannot be determined: #{candidates}" if candidates.size > 1
      candidates.empty? ? nil : candidates.first
    end

  end

end
