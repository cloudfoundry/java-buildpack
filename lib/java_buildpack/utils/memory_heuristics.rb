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

  # A utility for calculating the default Java memory settings.
  class MemoryHeuristics

    # @!attribute [r] default_heap_size_maximum
    #   @return [String] the default heap size expressed in kilobytes, e.g. '1024k'
    # @!attribute [r] default_permgen_size
    #   @return [String] the default permgen size expressed in kilobytes, e.g. '1024k'
    attr_reader :default_heap_size_maximum, :default_permgen_size

    # Creates an instance based on a hash containing memory settings, a configuration file containing weightings, and the application's memory size in $MEMORY_LIMIT.
    def initialize(args)
      config = MemoryHeuristics.load_config
      heap_weighting, permgen_weighting, native_weighting = MemoryHeuristics.check_config config

      memory_limit = ENV['MEMORY_LIMIT']
      raise ":memory_limit not specified in $MEMORY_LIMIT" unless memory_limit
      @memory_limit_k = MemoryHeuristics.kilobytes memory_limit

      @default_heap_size_maximum = MemoryHeuristics.size(@memory_limit_k * heap_weighting)
      @default_permgen_size = MemoryHeuristics.size(@memory_limit_k * permgen_weighting)
    end

    # @return [String] the application's memory limit expressed in kilobytes, e.g. '4096k'
    def memory_limit
      MemoryHeuristics.size(@memory_limit_k)
    end

    private

    MEMORY_HEURISTICS_YAML_FILE = 'config/memory_heuristics.yml'

    def self.load_config
      YAML.load_file(File.expand_path "../../../#{MEMORY_HEURISTICS_YAML_FILE}", File.dirname(__FILE__))
    end

    def self.check_config(config)
      heap_weighting = config['heap']
      permgen_weighting = config['permgen']
      native_weighting = config['native']

      raise "Heap weighting not specified in '#{MEMORY_HEURISTICS_YAML_FILE}'" unless heap_weighting
      raise "Permgen weighting not specified in '#{MEMORY_HEURISTICS_YAML_FILE}'" unless permgen_weighting
      raise "Native weighting not specified in '#{MEMORY_HEURISTICS_YAML_FILE}'" unless native_weighting
      raise "Invalid configuration in '#{MEMORY_HEURISTICS_YAML_FILE}': sum of weightings is greater than 1" if  heap_weighting + permgen_weighting + native_weighting > 1

      return heap_weighting, permgen_weighting, native_weighting
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
      f && f.floor == f
    rescue
      false
    end

    def self.size(size_k)
      size_k.floor.to_s + 'k'
    end

  end
end
