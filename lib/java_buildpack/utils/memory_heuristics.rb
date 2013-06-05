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

module JavaBuildpack

  # A utility for defaulting Java memory settings.
  class MemoryHeuristics

    # @!attribute [r] heap_size_maximum
    #   @return [String] the maximum heap size expressed in kilobytes, e.g. '1024k'
    attr_reader :heap_size_maximum

    # @!attribute [r] permgen_size_maximum
    #   @return [String, nil] the maximum permgen size expressed in kilobytes, e.g. '1024k', or nil if the maximum permgen size is not set
    attr_reader :permgen_size_maximum

    # @!attribute [r] stack_size
    #   @return [String] the stack size expressed in kilobytes, e.g. '1024k'
    attr_reader :stack_size

    # Creates an instance based on a hash containing memory settings, a configuration file containing weightings, and the application's memory size in $MEMORY_LIMIT.
    def initialize(args)
      heap_specified, permgen_specified, stack_specified = MemoryHeuristics.parse_args args
      heap_weighting, permgen_weighting, stack_weighting, native_weighting = MemoryHeuristics.get_config

      @memory_limit_k = MemoryHeuristics.determine_memory_limit

      default_heap = @memory_limit_k * heap_weighting
      if heap_specified
        @heap_size_maximum = heap_specified
        excess_heap = heap_specified - default_heap
      else
        excess_heap = 0
      end

      default_permgen = @memory_limit_k * permgen_weighting
      if permgen_specified
        @permgen_size_maximum = permgen_specified
        excess_permgen = permgen_specified - default_permgen
      else
        excess_permgen = 0
      end

      if stack_specified
        @stack_size = stack_specified
        # Estimate the total excess stack space assuming no more threads are needed.
        excess_stack = @memory_limit_k * ((stack_specified - DEFAULT_STACK_SIZE) / DEFAULT_STACK_SIZE) * stack_weighting
      else
        @stack_size = DEFAULT_STACK_SIZE
        excess_stack = 0
      end

      available_memory = @memory_limit_k * (heap_weighting + permgen_weighting + stack_weighting + native_weighting)
      total_unspecified_weighting = (heap_specified ? 0 : heap_weighting) + (permgen_specified ? 0 : permgen_weighting) + (stack_specified ? 0 : stack_weighting) + native_weighting

      excess_heap_ratio = excess_heap / total_unspecified_weighting
      excess_permgen_ratio = excess_permgen / total_unspecified_weighting
      excess_stack_ratio = excess_stack / total_unspecified_weighting

      if !heap_specified
        @heap_size_maximum = default_heap - heap_weighting * (excess_permgen_ratio + excess_stack_ratio)
      end

      if !permgen_specified
        @permgen_size_maximum = default_permgen - permgen_weighting * (excess_heap_ratio + excess_stack_ratio)
      end

      @heap_size_maximum = MemoryHeuristics.size @heap_size_maximum
      @permgen_size_maximum = MemoryHeuristics.size @permgen_size_maximum
      @stack_size = MemoryHeuristics.size @stack_size
    end

    # Returns the application's memory limit.
    #   @return [String] the application's memory limit expressed in kilobytes, e.g. '4096k'
    def memory_limit
      MemoryHeuristics.size(@memory_limit_k)
    end

    private

    MEMORY_HEURISTICS_YAML_FILE = 'config/memory_heuristics.yml'

    DEFAULT_STACK_SIZE = 1024

    def self.parse_args(args)
      heap_specified = args['heap_size_maximum']
      if heap_specified
        heap_specified = MemoryHeuristics.kilobytes heap_specified
      end

      permgen_specified = args['permgen_size_maximum']
      if permgen_specified
        permgen_specified = MemoryHeuristics.kilobytes permgen_specified
      end

      stack_specified = args['stack_size']
      if stack_specified
        stack_specified = MemoryHeuristics.kilobytes stack_specified
      end

      return heap_specified, permgen_specified, stack_specified
    end

    def self.get_config
      MemoryHeuristics.check_config MemoryHeuristics.load_config
    end

    def self.load_config
      YAML.load_file(File.expand_path "../../../#{MEMORY_HEURISTICS_YAML_FILE}", File.dirname(__FILE__))
    end

    def self.check_config(config)
      heap_weighting = validate_weighting(config, 'heap')
      permgen_weighting = validate_weighting(config, 'permgen')
      stack_weighting = validate_weighting(config, 'stack')
      native_weighting = validate_weighting(config, 'native')

      raise "Invalid configuration in '#{MEMORY_HEURISTICS_YAML_FILE}': sum of weightings is greater than 1" if  heap_weighting + permgen_weighting + stack_weighting + native_weighting > 1

      return heap_weighting, permgen_weighting, stack_weighting, native_weighting
    end

    def self.validate_weighting(config, weighting_name)
      weighting = config[weighting_name]
      raise "#{weighting_name} weighting not specified in '#{MEMORY_HEURISTICS_YAML_FILE}'" unless weighting
      raise "Invalid weighting '#{weighting}': not numeric" unless is_numeric weighting
      raise "Invalid weighting '#{weighting}': not positive" if weighting <= 0
      raise "Invalid weighting '#{weighting}': greater than 1" if weighting > 1
      weighting
    end

    def self.is_numeric(w)
      Float(w) rescue false
    end

    def self.determine_memory_limit
      memory_limit = ENV['MEMORY_LIMIT']
      raise ":memory_limit not specified in $MEMORY_LIMIT" unless memory_limit
      MemoryHeuristics.kilobytes memory_limit
    end

    def self.kilobytes(size)
      raise "Invalid memory size '#{size}'" if size.nil? || size.length < 2
      unit = size[-1]
      v = size[0..-2]
      raise "Invalid memory size '#{size}'" unless is_natural_number v
      v = size.to_i
      case unit
        when 'k', 'K'
          v
        when 'm', 'M'
          1024 * v
        when 'g', 'G'
          1024 * 1024 * v
        else
          raise "Invalid unit '#{unit}' in memory size '#{size}'"
      end
    end

    def self.is_natural_number(v)
      f = Float(v)
      f && f.floor == f && f >= 0
    rescue
      false
    end

    def self.size(size_k)
      size_k.floor.to_s + 'k'
    end

  end
end
