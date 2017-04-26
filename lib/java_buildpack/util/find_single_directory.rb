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

module JavaBuildpack
  module Util

    # Find the single directory in the root of the droplet
    #
    # @return [Pathname, nil] the single directory in the root of the droplet, otherwise +nil+
    def find_single_directory
      roots = (@droplet.root + '*').glob.select(&:directory?)
      roots.size == 1 ? roots.first : nil
    end

    module_function :find_single_directory

  end
end
