# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/util/find_single_directory'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Util
    module Play

      # Base class for Play application classes.
      class Base
        include JavaBuildpack::Util

        # Creates a new instance
        #
        # @param [JavaBuildpack::Component::Droplet] droplet the droplet to mutate
        def initialize(droplet)
          @droplet = droplet
        end

        # (see JavaBuildpack::Component::BaseComponent#compile)
        def compile
          update_file start_script, ORIGINAL_BOOTSTRAP, REPLACEMENT_BOOTSTRAP
          start_script.chmod 0o755
          augment_classpath
        end

        # Whether the play application has a JAR on its classpath
        #
        # @param [RegExp] pattern the pattern of the JAR to match
        # @return [Boolean] +true+ if at least one JAR matching the +pattern+ is found, +false+ otherwise
        def jar?(pattern)
          lib_dir.children.any? { |child| child.to_s =~ pattern }
        end

        # (see JavaBuildpack::Component::BaseComponent#release)
        def release
          @droplet.java_opts.add_system_property 'http.port', '$PORT'
          @droplet.environment_variables
                  .add_environment_variable 'PATH', "#{qualify_path(@droplet.java_home.root, @droplet.root)}/bin:$PATH"

          [
            @droplet.environment_variables.as_env_vars,
            @droplet.java_home.as_env_var,
            'exec',
            qualify_path(start_script, @droplet.root),
            java_opts
          ].flatten.compact.join(' ')
        end

        # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
        def supports?
          start_script&.exist? && play_jar
        end

        # Returns the version of the play application
        #
        # @return [String] the version of the play application
        def version
          play_jar.to_s.match(/.*play_.*-(.*)\.jar/)[1]
        end

        protected

        # Augments the classpath for the play application
        #
        # @return [Void]
        def augment_classpath
          raise "Method 'augment_classpath' must be defined"
        end

        # Returns the +JAVA_OPTS+ in the form that they need to be added to the command line
        #
        # @return [Array<String>] the +JAVA_OPTS+ in the form that they need to be added to the command line
        def java_opts
          raise "Method 'java_opts' must be defined"
        end

        # Returns the path to the play application library dir.  May return +nil+ if no library dir exists.
        #
        # @return [Pathname] the path to the play application library dir.  May return +nil+ if no library dir exists.
        def lib_dir
          raise "Method 'lib_dir' must be defined"
        end

        # Returns the path to the play application start script.  May return +nil+ if no script exists.
        #
        # @return [Pathname] the path to the play application start script.  May return +nil+ if no script exists.
        def start_script
          raise "Method 'start_script' must be defined"
        end

        # Updates the contents of a file
        #
        # @param [Pathname] path the path to the file
        # @param [Regexp, String] pattern the pattern to replace
        # @param [String] replacement the replacement content
        # @return [Void]
        def update_file(path, pattern, replacement)
          content = path.read.gsub pattern, replacement

          path.open('w') do |f|
            f.write content
            f.fsync
          end
        end

        private

        ORIGINAL_BOOTSTRAP = 'play.core.server.NettyServer'

        REPLACEMENT_BOOTSTRAP = 'org.cloudfoundry.reconfiguration.play.Bootstrap'

        private_constant :ORIGINAL_BOOTSTRAP, :REPLACEMENT_BOOTSTRAP

        def play_jar
          (lib_dir + '*play_*-*.jar').glob.first
        end

      end

    end
  end
end
