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
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack::Jre

  # A MemoryBucket is used to calculate default sizes for various type of memory
  class MemoryBucket

    # @!attribute [r] size
    #   @return [Numeric, nil] the size of the memory bucket in KB or nil if this has not been specified by the user or
    #                          defaulted
    attr_reader :size

    # Constructs a memory bucket.
    #
    # @param [String] name a non-empty, human-readable name for this memory bucket, used only in diagnostics
    # @param [Numeric] weighting a number between 0 and 1 corresponding to the proportion of total memory which this
    #                  memory bucket should consume by default
    # @param [Numeric, nil] size a user-specified size of the memory bucket in KB or nil if the user did not specify a
    #                            size
    # @param [Boolean] adjustable whether the size of this memory bucket can grow/shrink or is fixed. If the user
    #                             specified the size of the memory bucket, the size is fixed, regardless of the value of
    #                             this parameter, although the parameter value must still be valid. If total_memory is
    #                             +nil+, the size is fixed since no defaulting will occur.
    # @param [Numeric, nil] total_memory the total virtual memory size of the operating system process in KB or +nil+ if
    #                                    this is not known
    def initialize(name, weighting, size, adjustable, total_memory)
      @name = MemoryBucket.validate_name name
      @weighting = validate_weighting weighting
      @size_specified = size ? validate_memory_size(size, 'size') : nil
      @adjustable = (validate_adjustable adjustable) && !@size_specified && total_memory
      @total_memory = total_memory ? validate_memory_size(total_memory, 'total_memory') : nil
      @size = @size_specified || default_size
      logger = JavaBuildpack::Diagnostics::LoggerFactory.get_logger
      logger.debug { inspect }
    end

    # Returns the excess memory in this memory bucket.
    #
    # @return [Numeric] the excess memory in KB
    def excess
      if @total_memory
        @size_specified ? @size_specified - default_size : MemorySize::ZERO
      else
        MemorySize::ZERO
      end
    end

    # Returns the adjustable weighting of this memory bucket.
    #
    # @return [Numeric] the adjustable weighting
    def adjustable_weighting
      @adjustable ? @weighting : 0
    end

    # Adjusts the size by the appropriate proportion for this memory bucket.
    #
    # @param [Numeric] total_excess
    # @param [Numeric] total_adjustable_weighting
    def adjust(total_excess, total_adjustable_weighting)
      if @adjustable
        if total_adjustable_weighting == 0
          @size = MemorySize::ZERO
        else
          @size = default_size - (total_excess - excess) * @weighting / total_adjustable_weighting
        end
      end
    end

    # Returns the default memory size as a weighted proportion of total memory.
    #
    # @return [MemorySize, nil] the default memory size or nil if there is no default
    def default_size
      @total_memory ? @total_memory * @weighting : nil
    end

    protected

      attr_writer :size

    private

      def self.validate_name(name)
        raise "Invalid MemoryBucket name '#{name}'" if name.nil? || name.to_s.size == 0
        name
      end

      def validate_weighting(weighting)
        raise diagnose_weighting(weighting, 'not numeric') unless MemoryBucket.is_numeric weighting
        raise diagnose_weighting(weighting, 'negative') if weighting < 0
        raise diagnose_weighting(weighting, 'greater than 1') if weighting > 1
        weighting
      end

      def diagnose_weighting(weighting, reason)
        "Invalid weighting '#{@weighting}' for #{identify} : #{reason}"
      end

      def self.is_numeric(w)
        Float(w) rescue false
      end

      def identify
        "MemoryBucket #{@name}"
      end

      def validate_memory_size(size, parameter_name)
        raise "Invalid '#{parameter_name}' parameter of class '#{size.class}' for #{identify} : not a MemorySize" unless size.is_a? MemorySize
        size
      end

      def validate_adjustable(adjustable)
        raise "Invalid 'adjustable' parameter for #{identify} : not true or false" unless !!adjustable == adjustable
        adjustable
      end

  end

end
