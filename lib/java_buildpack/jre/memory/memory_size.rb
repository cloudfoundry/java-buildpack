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

require 'java_buildpack/jre'

module JavaBuildpack::Jre

  # A class representing the size of a category of memory.
  class MemorySize
    include Comparable

    # Creates a memory size based on a memory size string including a unit of 'K', 'M', or 'G'.
    #
    # @param [String] size a memory size including a unit
    def initialize(size)
      raise "Invalid memory size '#{size}'" if !size || size.length < 2
      unit = size[-1]
      v = size[0..-2]
      raise "Invalid memory size '#{size}'" unless MemorySize.is_integer v
      v = size.to_i
      # Store the number of bytes.
      case unit
      when 'b', 'B'
        @bytes = v
      when 'k', 'K'
        @bytes = v * KILO
      when 'm', 'M'
        @bytes = KILO * KILO * v
      when 'g', 'G'
        @bytes = KILO * KILO * KILO * v
      else
        raise "Invalid unit '#{unit}' in memory size '#{size}'"
      end
    end

    # Returns a memory size as a string including a unit. If the memory size is not a whole number, it is rounded down.
    # The returned unit is always kilobytes, megabytes, or gigabytes which are commonly used units.
    #
    # @return [String] the memory size as a string, e.g. "10K"
    def to_s
      kilobytes = (@bytes / KILO).round
      if kilobytes % KILO == 0
        megabytes = kilobytes / KILO
        if megabytes % KILO == 0
          gigabytes = megabytes / KILO
          gigabytes.to_s + 'G'
        else
          megabytes.to_s + 'M'
        end
      else
        kilobytes.to_s + 'K'
      end
    end

    # Compare this memory size with another memory size
    #
    # @param [MemorySize] other
    # @return [Numeric] the result
    def <=>(other)
      raise "Cannot compare a MemorySize to an instance of #{other.class}" unless other.is_a? MemorySize
      @bytes <=> other.bytes
    end

    # Add a memory size to this memory size.
    #
    # @param [MemorySize] other the memory size to add
    # @return [MemorySize] the result
    def +(other)
      raise "Cannot add an instance of #{other.class} to a MemorySize" unless other.is_a? MemorySize
      MemorySize.from_numeric(@bytes + other.bytes)
    end

    # Multiply this memory size by a numeric factor.
    #
    # @param [Numeric] other the factor to multiply by
    # @return [MemorySize] the result
    def *(other)
      raise "Cannot multiply a Memory size by an instance of #{other.class}" unless other.is_a? Numeric
      MemorySize.from_numeric((@bytes * other).round)
    end

    # Subtract a memory size from this memory size.
    #
    # @param [MemorySize] other the memory size to subtract
    # @return [MemorySize] the result
    def -(other)
      raise "Cannot subtract an instance of #{other.class} from a MemorySize" unless other.is_a? MemorySize
      MemorySize.from_numeric(@bytes - other.bytes)
    end

    # Divide a memory size by a memory size or a numeric value. The units are respected, so the result of diving by a
    # memory size is a numeric whereas the result of dividing by a numeric value is a memory size.
    #
    # @param [MemorySize, Numeric] other the memory size or numeric value to divide by
    # @return [MemorySize, Numeric] the result
    def /(other)
      return @bytes / other.bytes.to_f if other.is_a? MemorySize
      return MemorySize.from_numeric((@bytes / other.to_f).round) if other.is_a? Numeric
      raise "Cannot divide a MemorySize by an instance of #{other.class}"
    end

    protected

      # @!attribute [r] bytes
      #   @return [Numeric] the size in bytes of this memory size
      attr_reader :bytes

    private

      KILO = 1024

      def self.is_integer(v)
        f = Float(v)
        f && f.floor == f
      rescue
        false
      end

      def self.from_numeric(n)
        MemorySize.new("#{n.to_s}B")
      end

    public

      # Zero byte memory size
      ZERO = from_numeric 0

  end

end
