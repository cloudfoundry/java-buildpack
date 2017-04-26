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

require 'java_buildpack/util'
require 'pathname'

module JavaBuildpack
  module Util

    # A module encapsulating all of the utility components for caching
    module Cache

      # The location to find cached resources in the buildpack
      CACHED_RESOURCES_DIRECTORY = Pathname.new(File.expand_path('../../../../resources/cache', __FILE__))

    end

  end
end
