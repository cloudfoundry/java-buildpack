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

require 'java_buildpack/util/play/base'

module JavaBuildpack
  module Util
    module Play

      # Base class for inspection and modification of Play applications up to and including Play 2.1.x.
      class Pre22 < Base

        protected

        # (see JavaBuildpack::Util::Play::Base#java_opts)
        def java_opts
          @droplet.java_opts
        end

        # (see JavaBuildpack::Util::Play::Base#start_script)
        def start_script
          root ? root + 'start' : nil
        end

        # Returns the root of the play application
        #
        # @return [Pathname] the root of the play application
        def root
          raise "Method 'root' must be defined"
        end

      end

    end
  end
end
