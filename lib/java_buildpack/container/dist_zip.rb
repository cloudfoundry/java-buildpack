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
require 'java_buildpack/util/find_single_directory'
require 'java_buildpack/util/play/factory'
require 'java_buildpack/util/qualify_path'
require 'java_buildpack/util/start_script'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for +distZip+ style applications.
    class DistZip < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? DistZip.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        start_script.chmod 0755
        augment_classpath
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        [
          @droplet.java_home.as_env_var,
          @droplet.java_opts.as_env_var,
          'SERVER_PORT=$PORT',
          qualify_path(start_script, @droplet.root)
        ].flatten.compact.join(' ')
      end

      private

      PATTERN_APP_CLASSPATH = /^declare -r app_classpath=\"(.*)\"$/

      PATTERN_CLASSPATH = /^CLASSPATH=(.*)$/.freeze

      def augment_classpath
        content = start_script.read

        if content =~ PATTERN_CLASSPATH
          additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
            "$APP_HOME/#{additional_library.relative_path_from(root)}"
          end

          update_file start_script, content,
                      PATTERN_CLASSPATH, "CLASSPATH=#{additional_classpath.join(':')}:\\1"
        elsif content =~ PATTERN_APP_CLASSPATH
          additional_classpath = @droplet.additional_libraries.sort.map do |additional_library|
            "$app_home/#{additional_library.relative_path_from(start_script.dirname)}"
          end

          update_file start_script, content,
                      PATTERN_APP_CLASSPATH, "declare -r app_classpath=\"#{additional_classpath.join(':')}:\\1\""
        end
      end

      def jars?
        (lib_dir + '*.jar').glob.any?
      end

      def lib_dir
        root + 'lib'
      end

      def root
        find_single_directory || @droplet.root
      end

      def start_script
        JavaBuildpack::Util.start_script root
      end

      def supports?
        start_script && start_script.exist? && jars? && !JavaBuildpack::Util::Play::Factory.create(@droplet)
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
