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

require 'java_buildpack/util/play'
require 'java_buildpack/util/play/base'
require 'java_buildpack/util/start_script'
require 'shellwords'

module JavaBuildpack
  module Util
    module Play

      # Encapsulate inspection and modification of Play applications from Play 2.2.0 onwards.
      class Post22 < Base

        protected

        # (see JavaBuildpack::Util::Play::Base#augment_classpath)
        def augment_classpath
          additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
            "$app_home/#{additional_library.relative_path_from(start_script.dirname)}"
          end

          update_file start_script, /^declare -r app_classpath="(.*)"$/,
                      "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
        end

        # (see JavaBuildpack::Util::Play::Base#java_opts)
        def java_opts
          '$(for I in $JAVA_OPTS ; do echo "-J$I" ; done)'
        end

        # (see JavaBuildpack::Util::Play::Base#lib_dir)
        def lib_dir
          root + 'lib'
        end

        # (see JavaBuildpack::Util::Play::Base#start_script)
        def start_script
          JavaBuildpack::Util.start_script root
        end

        # Returns the root of the play application
        #
        # @return [Pathname] the root of the play application
        def root
          raise "Method 'root' must be defined"
        end

        private

        def bash_expression?(option)
          option =~ /\$\(expr/
        end

      end

    end
  end
end
