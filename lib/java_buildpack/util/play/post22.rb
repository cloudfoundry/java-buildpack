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
require 'java_buildpack/util/play/base'

module JavaBuildpack::Util::Play

  # Encapsulate inspection and modification of Play applications from Play 2.2.0 onwards.
  class Post22 < Base

    protected

    def augment_classpath
      additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
        "$app_home/#{additional_library.relative_path_from(start_script.dirname)}"
      end

      update_file start_script,
                  /^declare -r app_classpath=\"(.*)\"$/, "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
    end

    def java_opts
      @droplet.java_opts.map { |java_opt| "-J#{java_opt}" }
    end

    def lib_dir
      root + 'lib'
    end

    def start_script
      if root
        candidates = (root + 'bin/*').glob
        candidates.size == 1 ? candidates.first : candidates.find { |candidate| Pathname.new("#{candidate}.bat").exist? }
      else
        nil
      end
    end

    protected

    # Returns the root of the play application
    #
    # @return [Pathname] the root of the play application
    def root
      fail "Method 'root' must be defined"
    end

  end

end
