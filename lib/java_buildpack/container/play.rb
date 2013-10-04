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

require 'java_buildpack/base_component'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/play_utils'
require 'pathname'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Play applications.
  class Play < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Play Framework', context)

      @play_root = JavaBuildpack::Util::PlayUtils.root(@app_dir)
      @version = @play_root ? JavaBuildpack::Util::PlayUtils.version(@play_root) : nil
    end

    def detect
      @version ? id(@version) : nil
    end

    def compile
      shell "chmod +x #{JavaBuildpack::Util::PlayUtils.start_script @play_root}"
      add_libs_to_classpath
      replace_bootstrap @play_root
    end

    def release
      @java_opts << "-D#{KEY_HTTP_PORT}=$PORT"

      path_string = "PATH=#{File.join @java_home, 'bin'}:$PATH"
      java_home_string = ContainerUtils.space("JAVA_HOME=#{@java_home}")
      start_script_string = ContainerUtils.space(start_script_relative @play_root)
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@java_opts))

      "#{path_string}#{java_home_string}#{start_script_string}#{java_opts_string}"
    end

    protected

    # The unique indentifier of the component, incorporating the version of the dependency (e.g. +play-2.2.0+)
    #
    # @param [String] version the version of the dependency
    # @return [String] the unique identifier of the component
    def id(version)
      "play-#{version}"
    end

    private

    KEY_HTTP_PORT = 'http.port'.freeze

    def add_libs_to_classpath
      if JavaBuildpack::Util::PlayUtils.lib_play_jar @play_root
        add_libs_to_dist_classpath
      else
        add_libs_to_staged_classpath
      end
    end

    def add_libs_to_staged_classpath
      # Staged applications add all the JARs in the staged directory to the classpath, so add symbolic links to the staged directory.
      # Note: for staged applications, @app_dir = @play_root
      link_libs_to_classpath_directory(JavaBuildpack::Util::PlayUtils.staged @play_root)
    end

    def link_libs_to_classpath_directory(classpath_directory)
      ContainerUtils.libs(@play_root, @lib_directory).each do |lib|
        shell "ln -nsf ../#{lib} #{classpath_directory}"
      end
    end

    def add_libs_to_dist_classpath
      # Dist applications either list JARs in a classpath variable (e.g. in Play 2.1.3) or on a -cp parameter (e.g. in Play 2.0),
      # so add to the appropriate list.
      # Note: for dist applications, @play_root is an immediate subdirectory of @app_dir, so @app_dir is equivalent to @play_root/..
      script_dir_relative_path = Pathname.new(@app_dir).relative_path_from(Pathname.new(@play_root)).to_s

      additional_classpath = ContainerUtils.libs(@app_dir, @lib_directory).map do |lib|
        "$scriptdir/#{script_dir_relative_path}/#{lib}"
      end

      result = update_file JavaBuildpack::Util::PlayUtils.start_script(@play_root), /^classpath=\"(.*)\"$/, "classpath=\"#{additional_classpath.join(':')}:\\1\""
      unless result
        link_libs_to_classpath_directory(JavaBuildpack::Util::PlayUtils.lib @play_root)
      end
    end

    def replace_bootstrap(root)
      update_file JavaBuildpack::Util::PlayUtils.start_script(root), /play\.core\.server\.NettyServer/, 'org.cloudfoundry.reconfiguration.play.Bootstrap'
    end

    def start_script_relative(play_root)
      "./#{Pathname.new(JavaBuildpack::Util::PlayUtils.start_script(play_root)).relative_path_from(Pathname.new(@app_dir)).to_s}"
    end

    def update_file(file_name, pattern, replacement)
      content = File.open(file_name, 'r') { |file| file.read }
      result = content.gsub! pattern, replacement

      File.open(file_name, 'w') do |file|
        file.write content
        file.fsync
      end

      result
    end

  end

end
