# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack
  module Jre

    # This class represents a memory bucket for stack memory. This is treated differently to other memory buckets
    # which have absolute sizes since stack memory is specified in terms of the size of an individual stack with no
    # definition of how many stacks may exist.
    class StackMemoryBucket < MemoryBucket

      # Constructs a stack memory bucket.
      #
      # @param [Numeric] weighting a number between 0 and 1 corresponding to the proportion of total memory which this
      #                            memory bucket should consume by default
      # @param [MemoryRange, nil] range a user-specified range for the memory bucket or nil if the user did not specify
      #                                 a range
      def initialize(weighting, range)
        super('stack', weighting, range)
      end

      # Returns the default stack size.
      #
      # @return [MemorySize] the default stack size
      def default_size
        range.floor == 0 ? JVM_DEFAULT_STACK_SIZE : range.floor
      end

      JVM_DEFAULT_STACK_SIZE = MemorySize.new('1M').freeze

      private_constant :JVM_DEFAULT_STACK_SIZE

    end

  end
end
