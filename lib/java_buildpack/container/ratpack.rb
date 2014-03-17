# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

require 'java_buildpack/component/base_component'
require 'java_buildpack/container'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/ratpack_utils'
require 'java_buildpack/util/start_script'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Ratpack applications.
    class Ratpack < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      def initialize(context)
        super(context)
      end

      def detect
        JavaBuildpack::Util::RatpackUtils.is?(@application) ? id(version) : nil
      end

      def compile
        @droplet.additional_libraries.link_to lib_dir
      end

      def release
        @droplet.java_opts.add_system_property 'ratpack.port', '$PORT'

        [
          @droplet.java_home.as_env_var,
          @droplet.java_opts.as_env_var,
          "$PWD/#{start_script(root).relative_path_from(@application.root)}"
        ].flatten.compact.join(' ')
      end

      private

      RATPACK_CORE_FILE_PATTERN = 'lib/ratpack-core-*.jar'.freeze

      def id(version)
        "#{Ratpack.to_s.dash_case}=#{version}"
      end

      def lib_dir
        root + 'lib'
      end

      def root
        roots = (@droplet.root + '*').glob.select { |child| child.directory? }
        roots.size == 1 ? roots.first : @droplet.root
      end

      def version
        (root + RATPACK_CORE_FILE_PATTERN).glob.first.to_s.match(/.*ratpack-core-(.*)\.jar/)[1]
      end

    end

  end
end
