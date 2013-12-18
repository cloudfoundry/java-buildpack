# Encoding: utf-8
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

module JavaBuildpack::Jre

  # A class representing a permissible range of memory sizes.
  class MemoryRange

    # @!attribute [r] floor
    #   @return [MemorySize] the lower bound of this memory range
    attr_reader :floor

    # @!attribute [r] ceiling
    #   @return [MemorySize, nil] the upper bound of this memory range or +nil+ if there is no upper bound
    attr_reader :ceiling

    # Creates a memory range based on either a memory range string or lower and upper bounds expressed as MemorySizes.
    #
    # @param [MemorySize, String] value the lower bound of the range or a string range
    # @param [MemorySize, nil] ceiling the upper bound of the range
    def initialize(value, ceiling = nil)
      if value.is_a? String
        fail "Invalid combination of parameter types #{value.class} and #{ceiling.class}" unless ceiling.nil?
        lower_bound, upper_bound = get_bounds(value)
        @floor = create_memory_size lower_bound
        @ceiling = upper_bound ? create_memory_size(upper_bound) : nil
      else
        validate_memory_size value
        validate_memory_size ceiling unless ceiling.nil?
        @floor = value
        @ceiling = ceiling
      end
      fail "Invalid range: floor #{@floor} is higher than ceiling #{@ceiling}" if @ceiling && @floor > @ceiling
    end

    # Determines whether or not this range is bounded. Reads better than testing for a +nil+ ceiling.
    #
    # @return [Boolean] +true+ if and only if this range is bounded
    def bounded?
      !@ceiling.nil?
    end

    # Determines whether a given memory size falls in this range.
    #
    # @param [MemorySize] size the memory size to be checked
    # @return [Boolean] +true+ if and only if the given memory size falls in this range
    def contains?(size)
      @floor <= size && (@ceiling.nil? || size <= @ceiling)
    end

    # Constrains a given memory size to this range. If the size falls within the range, returns the size.
    # If the size is below the range, return the floor of the range. If the size is above the range,
    # return the ceiling of the range.
    #
    # @param [MemorySize] size the memory size to be constrained
    # @return [MemorySize] the constrained memory size
    def constrain(size)
      if size < @floor
        @floor
      else
        !@ceiling.nil? && size > @ceiling ? @ceiling : size
      end
    end

    # Returns true if and only if this range consists of a single value.
    #
    # @return [Boolean] whether or not this range consists of a single value
    def degenerate?
      @floor == @ceiling
    end

    # Multiply this memory range by a numeric factor.
    #
    # @param [Numeric] other the factor to multiply by
    # @return [MemoryRange] the result
    def *(other)
      fail "Cannot multiply a MemoryRange by an instance of #{other.class}" unless other.is_a? Numeric
      fail 'Cannot multiply an unbounded MemoryRange by 0' if !bounded? && other == 0
      MemoryRange.new(@floor * other, bounded? ? @ceiling * other : nil)
    end

    # Compare this memory range for equality with another memory range
    #
    # @param [MemoryRange] other
    # @return [Boolean] the result
    def ==(other)
      @floor == other.floor && @ceiling == other.ceiling
    end

    # Returns a string representation of this range.
    #
    # @return [String] the string representation of this range
    def to_s
      "#{@floor}..#{@ceiling ? @ceiling : ''}"
    end

    private

    RANGE_SEPARATOR = '..'

    def get_bounds(range)
      if range.index(RANGE_SEPARATOR)
        lower_bound, upper_bound = range.split(RANGE_SEPARATOR)
        lower_bound = '0' if lower_bound.nil? || lower_bound == ''
        return lower_bound, upper_bound
      else
        return range, range
      end
    end

    def create_memory_size(size)
      MemorySize.new(size)
    end

    def validate_memory_size(size)
      fail "Invalid MemorySize parameter of type #{size.class}" unless size.is_a? MemorySize
    end

  end

end
