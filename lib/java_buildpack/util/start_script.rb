# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

    # Find a start script relative to a root directory.  A start script is defined as existing in the +bin/+ directory
    # and being either the only file, or the only file with a counterpart named +<filename>.bat+
    #
    # @param [Pathname] root the root to search from
    # @return [Pathname, nil] the start script or +nil+ if one does not exist
    def start_script(root)
      return nil unless root

      candidates = (root + 'bin/*').glob

      if candidates.size == 1
        candidates.first
      else
        candidates.find { |candidate| Pathname.new("#{candidate}.bat").exist? }
      end
    end

    module_function :start_script

  end
end
