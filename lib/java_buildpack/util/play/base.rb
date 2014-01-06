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
require 'java_buildpack/util/qualify_path'

module JavaBuildpack::Util::Play

  # Base class for Play application classes.
  class Base
    include JavaBuildpack::Util

    def initialize(droplet)
      @droplet = droplet
    end

    # Delegate method for the component-level compile
    def compile
      update_file start_script, ORIGINAL_BOOTSTRAP, REPLACEMENT_BOOTSTRAP
      start_script.chmod 0755
      augment_classpath
    end

    # Whether the play application has a JAR on its classpath
    #
    # @param [RegExp] pattern the pattern of the JAR to match
    # @return [Boolean] +true+ if at least one JAR matching the +pattern+ is found, +false+ otherwise
    def has_jar?(pattern)
      lib_dir.children.any? { |child| child.to_s =~ pattern }
    end

    # Delegate method for the component-level release
    def release
      @droplet.java_opts.add_system_property 'http.port', '$PORT'

      [
          "PATH=#{@droplet.java_home.root}/bin:$PATH",
          @droplet.java_home.as_env_var,
          qualify_path(start_script, @droplet.root),
          java_opts
      ].compact.join(' ')
    end

    # Whether this play application type supports this application
    #
    # @return [Boolean] +true+ if this play application type supports this application, +false+ otherwise
    def supports?
      start_script && start_script.exist? && play_jar
    end

    # Returns the version of the play application
    #
    # @return [String] the version of the play application
    def version
      play_jar.to_s.match(/.*play_.*-(.*)\.jar/)[1]
    end

    protected

    # Augments the classpath for the play application
    def augment_classpath
      fail "Method 'augment_classpath' must be defined"
    end

    # Find the single directory in the root of the droplet
    #
    # @return [Pathname, nil] the single directory in the root of the droplet, otherwise +nil+
    def find_single_directory
      roots = (@droplet.root + '*').glob.select { |child| child.directory? }
      roots.size == 1 ? roots.first : nil
    end

    # Returns the +JAVA_OPTS+ in the form that they need to be added to the command line
    #
    # @return [Array<String>] the +JAVA_OPTS+ in the form that they need to be added to the command line
    def java_opts
      fail "Method 'java_opts' must be defined"
    end

    # Returns the path to the play application library dir.  May return +nil+ if no library dir exists.
    #
    # @return [Pathname] the path to the play application library dir.  May return +nil+ if no library dir exists.
    def lib_dir
      fail "Method 'lib_dir' must be defined"
    end

    # Returns the path to the play application start script.  May return +nil+ if no script exists.
    #
    # @return [Pathname] the path to the play application start script.  May return +nil+ if no script exists.
    def start_script
      fail "Method 'start_script' must be defined"
    end

    # Updates the contents of a file
    #
    # @param [Pathname] path the path to the file
    # @param [Regexp, String] pattern the pattern to replace
    # @param [String] replacement the replacement content
    def update_file(path, pattern, replacement)
      content = path.read.gsub pattern, replacement

      path.open('w') do |f|
        f.write content
        f.fsync
      end
    end

    private

    ORIGINAL_BOOTSTRAP = 'play.core.server.NettyServer'.freeze

    REPLACEMENT_BOOTSTRAP = 'org.cloudfoundry.reconfiguration.play.Bootstrap'.freeze

    def play_jar
      (lib_dir + '*play_*-*.jar').glob.first
    end

  end

end
