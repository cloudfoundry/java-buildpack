# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/util/filtering_pathname'
require 'java_buildpack/util/shell'
require 'java_buildpack/util/qualify_path'
require 'open3'
require 'tmpdir'

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

          puts "       Loaded Classes: #{class_count @configuration}, " \
               "Threads: #{stack_threads @configuration}"
        end
      end

      # Returns a fully qualified memory calculation command to be prepended to the buildpack's command sequence
      #
      # @return [String] the memory calculation command
      def memory_calculation_command
        "CALCULATED_MEMORY=$(#{memory_calculation_string(@droplet.root)}) && " \
          'echo JVM Memory Configuration: $CALCULATED_MEMORY && ' \
          'JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"'
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.environment_variables.add_environment_variable 'MALLOC_ARENA_MAX', 2
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def actual_class_count(root)
        (root + '**/*.class').glob.count +
          (root + '**/*.groovy').glob.count +
          (root + '**/*.jar').glob(File::FNM_DOTMATCH).reject(&:directory?)
                             .inject(0) { |a, e| a + archive_class_count(e) } +
          (@droplet.java_home.java_9_or_later? ? 42_215 : 0)
      end

      def archive_class_count(archive)
        `unzip -l #{archive} | grep '\\(\\.class\\|\\.groovy\\)$' | wc -l`.to_i
      end

      def class_count(configuration)
        root = JavaBuildpack::Util::FilteringPathname.new(@droplet.root, ->(_) { true }, true)
        configuration['class_count'] || (0.35 * actual_class_count(root)).ceil
      end

      def headroom(configuration)
        configuration['headroom']
      end

      def memory_calculator
        @droplet.sandbox + "bin/java-buildpack-memory-calculator-#{@version}"
      end

      def memory_calculator_tar
        platform = `uname -s` =~ /Darwin/ ? 'darwin' : 'linux'
        @droplet.sandbox + "bin/java-buildpack-memory-calculator-#{platform}"
      end

      def memory_calculation_string(relative_path)
        memory_calculation_string = [qualify_path(memory_calculator, relative_path)]
        memory_calculation_string << '-totMemory=$MEMORY_LIMIT'

        headroom = headroom(@configuration)
        memory_calculation_string << "-headRoom=#{headroom}" if headroom

        memory_calculation_string << "-loadedClasses=#{class_count @configuration}"
        memory_calculation_string << "-poolType=#{pool_type}"
        memory_calculation_string << "-stackThreads=#{stack_threads @configuration}"
        memory_calculation_string << '-vmOptions="$JAVA_OPTS"'

        memory_calculation_string.join(' ')
      end

      def pool_type
        @droplet.java_home.java_8_or_later? ? 'metaspace' : 'permgen'
      end

      def stack_threads(configuration)
        configuration['stack_threads']
      end

      def unpack_calculator(file)
        FileUtils.cp_r(file.path, memory_calculator)
      end

      def unpack_compressed_calculator(file)
        shell "tar xzf #{file.path} -C #{memory_calculator.parent} 2>&1"
        FileUtils.mv(memory_calculator_tar, memory_calculator)
      end

    end

  end
end
