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

require 'java_buildpack/util'
require 'java_buildpack/util/play_app_pre22_dist'
require 'java_buildpack/util/play_app_pre22_staged'
require 'java_buildpack/util/play_app_post22'

module JavaBuildpack::Util

  # Create instances of PlayAppPre22.
  class PlayAppFactory

    # Creates a Play application based on the given application directory.
    #
    # @param [String] app_dir the application directory
    def self.create(app_dir)
      recognizers = [PlayAppPre22Staged, PlayAppPre22Dist, PlayAppPost22].select do |play_app_class|
        play_app_class if play_app_class.recognizes? app_dir
      end
      fail "Play application in #{app_dir} is recognized by more than one Play application class: #{recognizers}" if recognizers.size > 1
      recognizers.empty? ? nil : recognizers[0].new(app_dir)
    end

  end

end
