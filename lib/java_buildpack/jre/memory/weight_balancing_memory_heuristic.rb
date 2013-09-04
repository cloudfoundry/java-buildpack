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

require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/memory_limit'
require 'java_buildpack/jre/memory/memory_size'
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/stack_memory_bucket'

module JavaBuildpack::Jre

  # A utility for defaulting Java memory settings.
  class WeightBalancingMemoryHeuristic

    # Creates an instance based on a hash containing memory settings, and the application's memory size in
    # $MEMORY_LIMIT.
    #
    # @param [Hash<String, Numeric>] sizes any sizings specified by the user
    # @param [Hash<String, Numeric>] heuristics the memory heuristics specified by the user
    # @param [Array<String>] valid_sizes the valid size keys
    # @param [Array<String>] valid_heuristics the valid heuristics keys
    # @param [Hash<String, String>] java_opts a mapping from a memory type to a +JAVA_OPTS+ option
    def initialize(sizes, heuristics, valid_sizes, valid_heuristics, java_opts)
      @logger = JavaBuildpack::Diagnostics::LoggerFactory.get_logger
      validate 'size', valid_sizes, sizes.keys
      validate 'heuristic', valid_heuristics, heuristics.keys

      @sizes = sizes
      @heuristics = heuristics
      @java_opts = java_opts
    end

    # Computes the JRE memory switch values based on the current state. Essentially, this takes the
    # specified memory sizes, applies default values to unspecified memory sizes, and then balances the positive or
    # negative excess of the specified memory sizes among the defaulted memory sizes which can be adjusted (essentially
    # any other than stack size). Raises an exception if the specified memory is too large. Issues a warning if the
    # specified memory is significantly smaller than the available memory. This all assumes the available memory is
    # known, which should be the usual case once Cloud Foundry passes $MEMORY_LIMIT to the buildpack.
    #
    # If the available memory is unknown, then perform no defaulting or balancing and do not diagnose the specified
    # memory as being too large or significantly smaller than the available memory.
    #
    # @return [Array<String>] an array of JRE memory switches with values
    def resolve
      memory_limit = MemoryLimit.memory_limit
      buckets = create_memory_buckets(@sizes, @heuristics, memory_limit)

      balance_buckets(@sizes, buckets, memory_limit)
      issue_memory_wastage_warning(buckets) if memory_limit
      issue_close_to_default_warnings(buckets, @heuristics, memory_limit)

      buckets.map { |type, bucket| "#{@java_opts[type]}#{bucket.size}" if bucket.size && @java_opts.key?(type) }.compact
    end

    private

    NATIVE_MEMORY_WARNING_FACTOR = 3

    CLOSE_TO_DEFAULT_FACTOR = 0.1

    def balance_buckets(sizes, buckets, memory_limit)
      total_excess = MemorySize::ZERO
      total_adjustable_weighting = 0

      buckets.each_value do |bucket|
        xs = bucket.excess
        total_excess = total_excess + xs
        total_adjustable_weighting += bucket.adjustable_weighting
      end

      buckets.each_value do |bucket|
        bucket.adjust(total_excess, total_adjustable_weighting)
        raise "Total memory #{memory_limit} exceeded by configured memory #{sizes}" if bucket.size && bucket.size < MemorySize::ZERO
      end
    end

    def create_memory_bucket(type, weighting, size, memory_limit)
      if type == 'stack'
        StackMemoryBucket.new(weighting, size, memory_limit)
      else
        MemoryBucket.new(type, weighting, size, true, memory_limit)
      end
    end

    def create_memory_buckets(sizes, heuristics, memory_limit)
      buckets = {}
      total_weighting = 0

      heuristics.each_pair do |type, weighting|
        size = nil_safe_size sizes[type]
        buckets[type] = create_memory_bucket(type, weighting, size, memory_limit)
        total_weighting += weighting
      end

      raise 'Invalid configuration: sum of weightings is greater than 1' if total_weighting > 1

      buckets
    end

    def issue_memory_wastage_warning(buckets)
      native_bucket = buckets['native']
      if native_bucket && native_bucket.size > native_bucket.default_size * NATIVE_MEMORY_WARNING_FACTOR
        @logger.warn "There is #{NATIVE_MEMORY_WARNING_FACTOR} times more spare native memory than the default, so configured Java memory may be too small."
      end
    end

    def nil_safe_size(size)
      size ? MemorySize.new(size) : nil
    end

    def validate(type, expected, actual)
      actual.each do |key|
        raise "'#{key}' is not a valid memory #{type}" unless expected.include? key
      end
    end

    def issue_close_to_default_warnings(buckets, heuristics, memory_limit)
      # Check each specified memory size to see if it is close to the default.
      buckets.each do |type, bucket|
        check_close_to_default(type, bucket) if @sizes[type]
      end
    end

    def check_close_to_default(type, bucket)
      default_size = bucket.default_size
      if default_size
        actual_size = bucket.size
        if default_size != MemorySize::ZERO
          factor = ((actual_size - default_size) / default_size).abs
          @logger.debug { "factor for memory size #{type} is #{factor}" }
        end
        if (default_size == MemorySize::ZERO && actual_size == MemorySize::ZERO) || (factor && (factor < CLOSE_TO_DEFAULT_FACTOR))
          @logger.warn "The configured value #{actual_size} of memory size #{type} is close to the default value #{default_size}. Consider deleting the configured value and taking the default."
        end
      end
    end

  end

end
