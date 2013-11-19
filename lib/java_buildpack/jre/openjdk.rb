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

require 'fileutils'
require 'java_buildpack/diagnostics/common'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/resource_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk < JavaBuildpack::VersionedDependencyComponent

    # Filename of killjava script used to kill the JVM on OOM.
    KILLJAVA_FILE_NAME = 'killjava'.freeze

    def initialize(context)
      super('OpenJDK', context)
      @java_home.concat JAVA_HOME
    end

    def compile
      download { |file| expand file }
      copy_killjava_script
    end

    def release
      @java_opts << "-XX:OnOutOfMemoryError=#{JavaBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{KILLJAVA_FILE_NAME}"
      @java_opts << '-Djava.io.tmpdir=$TMPDIR'
      @java_opts.concat memory
    end

    protected

    def supports?
      true
    end

    private

    JAVA_HOME = '.java'.freeze

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

    KEY_MEMORY_SIZES = 'memory_sizes'.freeze

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding JRE to #{JAVA_HOME} "

      shell "rm -rf #{java_home}"
      shell "mkdir -p #{java_home}"
      shell "tar xzf #{file.path} -C #{java_home} --strip 1 2>&1"

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def java_home
      File.join @app_dir, JAVA_HOME
    end

    def memory
      sizes = @configuration[KEY_MEMORY_SIZES] || {}
      heuristics = @configuration[KEY_MEMORY_HEURISTICS] || {}
      OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
    end

    def copy_killjava_script
      resources = JavaBuildpack::Util::ResourceUtils.get_resources(File.join('openjdk', 'diagnostics'))
      killjava_file_content = File.read(File.join resources, KILLJAVA_FILE_NAME)
      updated_content = killjava_file_content.gsub(/@@LOG_FILE_NAME@@/, JavaBuildpack::Diagnostics::LOG_FILE_NAME)
      diagnostic_dir = JavaBuildpack::Diagnostics.get_diagnostic_directory @app_dir
      FileUtils.mkdir_p diagnostic_dir
      File.open(File.join(diagnostic_dir, KILLJAVA_FILE_NAME), 'w', 0755) do |file|
        file.write updated_content
        file.fsync
      end
    end

  end

end
