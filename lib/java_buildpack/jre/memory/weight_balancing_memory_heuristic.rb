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

require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/memory_limit'
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/stack_memory_bucket'

module JavaBuildpack::Jre

  # A utility for defaulting Java memory settings.
  class WeightBalancingMemoryHeuristic

    # Creates an instance based on a hash containing memory settings, and the application's memory size in
    # $MEMORY_LIMIT.
    #
    # @param [Hash<String, String>] sizes any sizes specified by the user
    # @param [Hash<String, Numeric>] heuristics the memory heuristics specified by the user
    # @param [Array<String>] valid_types the valid types of memory
    # @param [Hash<String, String>] java_opts a mapping from a memory type to a +JAVA_OPTS+ option
    def initialize(sizes, heuristics, valid_types, java_opts)
      @logger = JavaBuildpack::Logging::LoggerFactory.get_logger WeightBalancingMemoryHeuristic
      validate 'size', valid_types, sizes.keys
      validate 'heuristic', valid_types, heuristics.keys
      @memory_limit = MemoryLimit.memory_limit
      @sizes        = sizes
      @heuristics   = heuristics
      @java_opts    = java_opts
    end

    # Computes the JRE memory switch values based on the current state.
    #
    # @return [Array<String>] an array of JRE memory switches with values
    def resolve
      buckets = create_memory_buckets(@sizes, @heuristics)

      if @memory_limit
        allocate_by_balancing(buckets)
      else
        allocate_lower_bounds(buckets)
      end

      set_switches(buckets)
    end

    private

    NATIVE_MEMORY_WARNING_FACTOR = 3

    TOTAL_MEMORY_WARNING_FACTOR = 0.8

    CLOSE_TO_DEFAULT_FACTOR = 0.1

    def allocate_lower_bounds(buckets)
      buckets.each_value do |bucket|
        bucket.size = bucket.range.floor
      end
    end

    def weighted_proportion(bucket, buckets)
      apply_weighting_to_memory_limit(bucket, calculate_total_weighting(buckets))
    end

    def apply_weighting_to_memory_limit(bucket, total_weighting)
      apply_weighting(@memory_limit, bucket, total_weighting)
    end

    def apply_weighting(memory, bucket, total_weighting)
      (memory * bucket.weighting) / total_weighting
    end

    def allocate_by_balancing(buckets)
      stack_bucket = buckets['stack']
      if stack_bucket
        # Convert stack range from range of stack sizes to range of total stack memory
        buckets['stack'], num_threads = normalise_stack_bucket(stack_bucket, buckets)
      end

      balance_buckets(buckets)

      issue_memory_wastage_warning(buckets)
      issue_close_to_default_warnings(buckets)

      if stack_bucket
        # Convert stack size from total stack memory to stack size
        stack_bucket.size = buckets['stack'].size / num_threads
        buckets['stack']  = stack_bucket
      end
    end

    def normalise_stack_bucket(stack_bucket, buckets)
      stack_memory      = weighted_proportion(stack_bucket, buckets)
      num_threads       = [stack_memory / stack_bucket.default_size, 1].max
      normalised_bucket = MemoryBucket.new('normalised stack', stack_bucket.weighting, stack_bucket.range * num_threads)
      return normalised_bucket, num_threads # rubocop:disable RedundantReturn
    end

    def balance_buckets(buckets)
      remaining_buckets = buckets.clone
      remaining_memory  = @memory_limit
      deleted           = true
      while !remaining_buckets.empty? && deleted
        remaining_memory, deleted = balance_remainder(remaining_buckets, remaining_memory)
      end
    end

    def balance_remainder(remaining_buckets, remaining_memory)
      deleted         = false
      total_weighting = calculate_total_weighting remaining_buckets

      allocated_memory = MemorySize::ZERO
      remaining_buckets.each do |type, bucket|
        size = apply_weighting(remaining_memory, bucket, total_weighting)
        if bucket.range.contains? size
          bucket.size = size
        else
          allocated_memory = constrain_bucket_size(allocated_memory, bucket, size)
          remaining_buckets.delete type
          deleted = true
        end
      end
      remaining_memory -= allocated_memory
      fail "Total memory #{@memory_limit} exceeded by configured memory #{@sizes}" if remaining_memory < 0
      return remaining_memory, deleted # rubocop:disable RedundantReturn
    end

    def constrain_bucket_size(allocated_memory, bucket, size)
      constrained_size = bucket.range.constrain(size)
      bucket.size      = constrained_size
      allocated_memory + constrained_size
    end

    def calculate_total_weighting(buckets)
      total_weighting = 0
      buckets.each_value do |bucket|
        total_weighting += bucket.weighting
      end
      total_weighting
    end

    def create_memory_bucket(type, weighting, range)
      if type == 'stack'
        StackMemoryBucket.new(weighting, range)
      else
        MemoryBucket.new(type, weighting, range)
      end
    end

    def create_memory_buckets(sizes, heuristics)
      buckets = {}

      heuristics.each_pair do |type, weighting|
        range         = nil_safe_range sizes[type]
        buckets[type] = create_memory_bucket(type, weighting, range)
      end

      buckets
    end

    def issue_memory_wastage_warning(buckets)
      native_bucket = buckets['native']
      if native_bucket && native_bucket.range.floor == 0
        if native_bucket.size > weighted_proportion(native_bucket, buckets) * NATIVE_MEMORY_WARNING_FACTOR
          @logger.warn { "There is more than #{NATIVE_MEMORY_WARNING_FACTOR} times more spare native memory than the default, so configured Java memory may be too small or available memory may be too large" }
        end
      end

      total_size = MemorySize::ZERO
      buckets.each_value { |bucket| total_size += bucket.size }
      if @memory_limit * TOTAL_MEMORY_WARNING_FACTOR > total_size
        @logger.warn { "The allocated Java memory sizes total #{total_size} which is less than #{TOTAL_MEMORY_WARNING_FACTOR} of the available memory, so configured Java memory sizes may be too small or available memory may be too large" }
      end
    end

    def nil_safe_range(size)
      size ? MemoryRange.new(size) : MemoryRange.new('..')
    end

    def validate(type, expected, actual)
      actual.each do |key|
        fail "'#{key}' is not a valid memory #{type}" unless expected.include? key
      end
    end

    def issue_close_to_default_warnings(buckets)
      total_weighting = calculate_total_weighting buckets
      buckets.each do |type, bucket|
        check_close_to_default(type, bucket, total_weighting) if type != 'stack' && @sizes[type]
      end
    end

    def check_close_to_default(type, bucket, total_weighting)
      if bucket.range.degenerate?
        default_size = apply_weighting_to_memory_limit(bucket, total_weighting)
        actual_size  = bucket.size
        if default_size > 0
          factor = ((actual_size - default_size) / default_size).abs
          @logger.debug { "factor for memory size #{type} is #{factor}" }
        end
        if (default_size == 0 && actual_size == 0) || (factor && (factor < CLOSE_TO_DEFAULT_FACTOR))
          @logger.warn { "The computed value #{actual_size} of memory size #{type} is close to the default value #{default_size}. Consider taking the default." }
        end
      end
    end

    def set_switches(buckets)
      buckets.map { |type, bucket| @java_opts[type][bucket.size] if bucket.size && bucket.size > 0 && @java_opts.key?(type) }.flatten(1).compact
    end

  end

end
