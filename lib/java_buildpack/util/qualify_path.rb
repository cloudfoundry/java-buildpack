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

    # Qualifies the path such that is is formatted as +$PWD/<path>+.  Also ensures that the path is relative to a root,
    # which defaults to the +@droplet_root+ of the class.
    #
    # @param [Pathname] path the path to qualify
    # @param [Pathname] root the root to make relative to
    # @return [String] the qualified path
    def qualify_path(path, root = @droplet_root)
      "$PWD/#{path.relative_path_from(root)}"
    end

  end
end
