# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/jre'
require 'java_buildpack/util/shell'
require 'java_buildpack/util/qualify_path'
require 'open3'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for the OpenJDK-like memory calculator
    class OpenJDKLikeMemoryCalculator < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri) do |file|
          FileUtils.mkdir_p memory_calculator.parent
          if @version[0] < '2'
            unpack_calculator file
          else
            unpack_compressed_calculator file
          end
          memory_calculator.chmod 0o755
        end

        show_settings memory_calculation_string(Pathname.new(Dir.pwd))
      end

      # Returns a fully qualified memory calculation command to be prepended to the buildpack's command sequence
      #
      # @return [String] the memory calculation command
      def memory_calculation_command
        "CALCULATED_MEMORY=$(#{memory_calculation_string(@droplet.root)})"
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_preformatted_options '$CALCULATED_MEMORY'
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def memory_calculator
        @droplet.sandbox + "bin/java-buildpack-memory-calculator-#{@version}"
      end

      def memory_calculator_tar
        platform = `uname -s` =~ /Darwin/ ? 'darwin' : 'linux'
        @droplet.sandbox + "bin/java-buildpack-memory-calculator-#{platform}"
      end

      def memory_calculation_string(relative_path)
        "#{qualify_path memory_calculator, relative_path} -memorySizes=#{memory_sizes @configuration} " \
              "-memoryWeights=#{memory_weights @configuration} -memoryInitials=#{memory_initials @configuration}" \
              "#{stack_threads @configuration} -totMemory=$MEMORY_LIMIT"
      end

      def memory_sizes(configuration)
        memory_sizes = version_specific configuration['memory_sizes']
        memory_sizes.map { |k, v| "#{k}:#{v}" }.join(',')
      end

      def memory_weights(configuration)
        memory_heuristics = version_specific configuration['memory_heuristics']
        memory_heuristics.map { |k, v| "#{k}:#{v}" }.join(',')
      end

      def memory_initials(configuration)
        memory_initials = version_specific configuration['memory_initials']
        memory_initials.map { |k, v| "#{k}:#{v}" }.join(',')
      end

      def unpack_calculator(file)
        FileUtils.cp_r(file.path, memory_calculator)
      end

      def unpack_compressed_calculator(file)
        shell "tar xzf #{file.path} -C #{memory_calculator.parent} 2>&1"
        FileUtils.mv(memory_calculator_tar, memory_calculator)
      end

      def stack_threads(configuration)
        configuration['stack_threads'] ? " -stackThreads=#{configuration['stack_threads']}" : ''
      end

      def version_specific(configuration)
        if @droplet.java_home.java_8_or_later?
          configuration.delete 'permgen'
        else
          configuration.delete 'metaspace'
        end

        configuration
      end

      def show_settings(*args)
        Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
          status         = wait_thr.value
          stderr_content = stderr.gets nil
          stdout_content = stdout.gets nil

          puts "       #{stderr_content}" if stderr_content

          raise unless status.success?
          puts "       Memory Settings: #{stdout_content}"
        end
      end

    end

  end
end
