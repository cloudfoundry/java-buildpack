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

require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/memory_limit'
require 'java_buildpack/jre/memory/memory_size'
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/stack_memory_bucket'

module JavaBuildpack::Jre

  # A utility for defaulting Java memory settings.
  class WeightBalancingMemoryHeuristic

    # @!attribute [r] output
    #   @return [Hash] a hash of memory types and corresponding memory sizes, e.g. {'memory-type' => '1M'}
    attr_reader :output

    # Creates an instance based on a configuration file containing weightings, the name of the weighting hash with the configuration file, a hash containing memory settings, and the application's memory size in $MEMORY_LIMIT.
    def initialize(weighting_configuration_filename, weightings_name, args)

      memory_limit = MemoryLimit.memory_limit

      buckets = WeightBalancingMemoryHeuristic.create_memory_buckets(args, memory_limit, weighting_configuration_filename, weightings_name)

      WeightBalancingMemoryHeuristic.balance_buckets(args, buckets, memory_limit)

      WeightBalancingMemoryHeuristic.issue_memory_wastage_warning(buckets) if memory_limit

      @output = {}
      buckets.each_pair do |memory_type, bucket|
        @output[memory_type] = bucket.size.to_s if bucket.size
      end
    end

    private

    def self.create_memory_buckets(args, memory_limit, weighting_configuration_filename, weightings_name)
      config = WeightBalancingMemoryHeuristic.load_config(weighting_configuration_filename, weightings_name)

      buckets = {}
      total_weighting = 0
      config.each_pair do |memory_type, weighting|
        value = args[memory_type]
        buckets[memory_type] = WeightBalancingMemoryHeuristic.create_memory_bucket(memory_type, weighting,
                                                                                   value ? MemorySize.new(value) : nil,
                                                                                   memory_limit)
        total_weighting += weighting
      end

      raise "Invalid configuration in 'config/#{weighting_configuration_filename}': sum of weightings is greater than 1" if total_weighting > 1
      buckets
    end

    def self.balance_buckets(args, buckets, memory_limit)
      total_excess = MemorySize.ZERO
      total_adjustable_weighting = 0
      buckets.each_value do |bucket|
        xs = bucket.excess
        total_excess = total_excess + xs
        total_adjustable_weighting += bucket.adjustable_weighting
      end

      buckets.each_value do |bucket|
        bucket.adjust(total_excess, total_adjustable_weighting)
        raise "Total memory #{memory_limit} exceeded by configured memory #{args}" if bucket.size && bucket.size < MemorySize.ZERO
      end
    end

    NATIVE_MEMORY_WARNING_FACTOR = 3

    def self.load_config(weighting_configuration_filename, weightings_name)
      config = YAML.load_file(File.expand_path "../../../../config/#{weighting_configuration_filename}", File.dirname(__FILE__))
      openjdk = extract_hash(config, weighting_configuration_filename, 'openjdk')
      memory_heuristics = extract_hash(openjdk, weighting_configuration_filename, 'memory_heuristics')
      extract_hash(memory_heuristics, weighting_configuration_filename, weightings_name)
    end

    def self.extract_hash(config, weighting_configuration_filename, hash_name)
      hash = config[hash_name]
      raise "Value of '#{hash_name}' missing from config/#{weighting_configuration_filename}" unless hash
      hash
    end

    def self.create_memory_bucket(memory_type, weighting, size, total_memory)
      if memory_type == 'stack'
        StackMemoryBucket.new(weighting, size, total_memory)
      else
        MemoryBucket.new(memory_type, weighting, size, true, total_memory)
      end
    end

    def self.issue_memory_wastage_warning(buckets)
      native_bucket = buckets['native']
      if native_bucket && native_bucket.size > native_bucket.default_size * NATIVE_MEMORY_WARNING_FACTOR
        $stderr.puts "-----> WARNING: there is #{NATIVE_MEMORY_WARNING_FACTOR} times more spare native memory than the default, so configured Java memory may be too small."
      end
    end

  end
end
