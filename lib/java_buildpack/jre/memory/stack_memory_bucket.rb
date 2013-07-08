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
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack::Jre

  # This class represents a memory bucket for stack memory. This is treated differently to other memory buckets
  # which have absolute sizes since stack memory is specified in terms of the size of an individual stack with no
  # definition of how many stacks may exist.
  class StackMemoryBucket < MemoryBucket

    # Constructs a stack memory bucket.
    #
    # @param [Numeric] weighting a number between 0 and 1 corresponding to the proportion of total memory which this
    #                            memory bucket should consume by default
    # @param [Numeric, nil] size a user-specified size of the memory bucket in KB or nil if the user did not specify a
    #                            size
    # @param [Numeric] total_memory the total virtual memory size of the operating system process in KB
    def initialize(weighting, size, total_memory)
      super('stack', weighting, size, false, total_memory)
      @weighting = weighting
      @total_memory = total_memory
      set_size(DEFAULT_STACK_SIZE) unless size
    end

    # Returns the excess memory in this memory bucket.
    #
    # @return [Numeric] the excess memory in KB
    def excess
      if @total_memory
        size ? @total_memory * @weighting * ((size - DEFAULT_STACK_SIZE) / DEFAULT_STACK_SIZE) : 0
      else
        MemorySize.ZERO
      end
    end

    # Returns the default stack size.
    #
    # @return [MemorySize, nil] the default memory size or nil if there is no default
    def default_size
      DEFAULT_STACK_SIZE
    end

    private

    DEFAULT_STACK_SIZE = MemorySize.new('1024K') # 1 MB

  end

end
