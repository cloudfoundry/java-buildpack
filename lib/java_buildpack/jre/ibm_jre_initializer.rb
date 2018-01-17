# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2017 the original author or authors.
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
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for selecting a JRE.
    class IbmJreInitializer < JavaBuildpack::Component::VersionedDependencyComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        @application    = context[:application]
        @component_name = context[:component_name]
        @configuration  = context[:configuration]
        @droplet        = context[:droplet]

        @droplet.java_home.root = @droplet.sandbox + 'jre/'
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @version, @uri             = JavaBuildpack::Repository::ConfiguredItem.find_item(@component_name,
                                                                                         @configuration)
        @droplet.java_home.version = @version
        super
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download(@version, @uri, @component_name) do |file|
          with_timing "Installing #{@component_name} to #{@droplet.sandbox.relative_path_from(@droplet.root)}" do
            install_bin(@droplet.sandbox, file)
          end
        end
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('java.io.tmpdir', '$TMPDIR')
          .add_preformatted_options('-Xtune:virtualized')
          .add_preformatted_options('-Xshareclasses:none')

        @droplet.java_opts.concat mem_opts
      end

      private

      # constant HEAP_RATIO is the ratio of memory assigned to the heap
      # as against the container total and is set using -Xmx.
      HEAP_RATIO = 0.75

      KILO = 1024

      private_constant :HEAP_RATIO, :KILO

      def install_bin(target_directory, file)
        FileUtils.mkdir_p target_directory
        response_file = Tempfile.new('response.properties')
        response_file.puts('INSTALLER_UI=silent')
        response_file.puts('LICENSE_ACCEPTED=TRUE')
        response_file.puts("USER_INSTALL_DIR=#{target_directory}")
        response_file.close

        File.chmod(0o755, file.path) unless File.executable?(file.path)
        shell "#{file.path} -i silent -f #{response_file.path} 2>&1"
      end

      def mem_opts
        mopts        = []
        total_memory = memory_limit_finder
        if total_memory.nil?
          # if no memory option has been set by cloudfoundry, we just assume defaults
        else
          calculated_heap_ratio = heap_ratio_verification(heap_ratio)
          heap_size             = heap_size_calculator(total_memory, calculated_heap_ratio)
          mopts.push "-Xmx#{heap_size}"
        end
        mopts
      end

      def heap_ratio
        @configuration['heap_ratio'] || HEAP_RATIO
      end

      def memory_limit_finder
        memory_limit = ENV['MEMORY_LIMIT']
        return nil unless memory_limit
        memory_limit_size = memory_size_bytes(memory_limit)
        raise "Invalid negative $MEMORY_LIMIT #{memory_limit}" if memory_limit_size.negative?
        memory_limit_size
      end

      def memory_size_bytes(size)
        if size == '0'
          bytes = 0
        else
          raise "Invalid memory size '#{size}'" if !size || size.length < 2
          unit  = size[-1]
          value = size[0..-2]
          raise "Invalid memory size '#{size}'" unless check_is_integer? value
          value = size.to_i
          # store the bytes
          bytes = calculate_bytes(unit, value)
        end
        bytes
      end

      def calculate_bytes(unit, value)
        if %w[b B].include?(unit)
          bytes = value
        elsif %w[k K].include?(unit)
          bytes = KILO * value
        elsif %w[m M].include?(unit)
          bytes = KILO * KILO * value
        elsif %w[g G].include?(unit)
          bytes = KILO * KILO * KILO * value
        else
          raise "Invalid unit '#{unit}' in memory size"
        end
        bytes
      end

      def check_is_integer?(v)
        v = Float(v)
        v && v.floor == v
      end

      def heap_size_calculator(membytes, heapratio)
        memory_size_minified(membytes * heapratio)
      end

      def memory_size_minified(membytes)
        giga = membytes / 2**(10 * 3)
        mega = membytes / 2**(10 * 2)
        kilo = (membytes / 2**(10 * 1)).round
        if check_is_integer?(giga)
          minified_size_calculator(giga, 'G')
        elsif check_is_integer?(mega)
          minified_size_calculator(mega, 'M')
        elsif check_is_integer?(kilo)
          minified_size_calculator(kilo, 'K')
        end
      end

      def minified_size_calculator(order, char)
        order.to_i.to_s + char
      end

      def heap_ratio_verification(ratio)
        raise 'Invalid heap ratio' unless ratio.is_a? Numeric
        raise 'heap ratio cannot be greater than 100%' unless ratio <= 1
        ratio
      end

    end

  end
end
