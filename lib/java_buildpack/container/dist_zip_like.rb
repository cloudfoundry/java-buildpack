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

require 'java_buildpack/component/base_component'
require 'java_buildpack/container'
require 'java_buildpack/util/find_single_directory'
require 'java_buildpack/util/qualify_path'
require 'java_buildpack/util/start_script'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for selecting a `distZip`-like container.
    class DistZipLike < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? id : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        start_script(root).chmod 0o755
        augment_classpath_content
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'

        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          qualify_path(start_script(root), @droplet.root)
        ].flatten.compact.join(' ')
      end

      protected

      # The id of this container
      #
      # @return [String] the id of this container
      def id
        raise "Method 'id' must be defined"
      end

      # The root directory of the application
      #
      # @return [Pathname] the root directory of the application
      def root
        find_single_directory || @droplet.root
      end

      # Whether or not this component supports this application
      #
      # @return [Boolean] whether or not this component supports this application
      def supports?
        raise "Method 'supports?' must be defined"
      end

      private

      PATTERN_APP_CLASSPATH = /^declare -r app_classpath=\"(.*)\"$/

      PATTERN_CLASSPATH = /^CLASSPATH=(.*)$/

      private_constant :PATTERN_APP_CLASSPATH, :PATTERN_CLASSPATH

      def augment_app_classpath(content)
        additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
          "$app_home/#{additional_library.relative_path_from(start_script(root).dirname)}"
        end

        update_file start_script(root), content,
                    PATTERN_APP_CLASSPATH, "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
      end

      def augment_classpath(content)
        additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
          "$APP_HOME/#{additional_library.relative_path_from(root)}"
        end

        update_file start_script(root), content,
                    PATTERN_CLASSPATH, "CLASSPATH=#{additional_classpath.join(':')}:\\1"
      end

      def augment_classpath_content
        content = start_script(root).read

        if content =~ PATTERN_CLASSPATH
          augment_classpath content
        elsif content =~ PATTERN_APP_CLASSPATH
          augment_app_classpath content
        end
      end

      def update_file(path, content, pattern, replacement)
        path.open('w') do |f|
          f.write content.gsub pattern, replacement
          f.fsync
        end
      end

    end

  end
end
