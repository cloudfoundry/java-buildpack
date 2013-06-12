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
require 'java_buildpack/jre/memory/stack_memory_bucket'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

module JavaBuildpack::Jre

  # A utility for defaulting Java memory settings.
  class MemoryHeuristicsOpenJDKPre8

    # @!attribute [r] heap
    #   @return [String] the maximum heap size, e.g. '1M'
    attr_reader :heap

    # @!attribute [r] permgen
    #   @return [String, nil] the maximum permgen size, e.g. '1M', or nil if the maximum permgen size is not set
    attr_reader :permgen

    # @!attribute [r] stack
    #   @return [String] the stack size, e.g. '1M'
    attr_reader :stack

    # Creates an instance based on a hash containing memory settings, a configuration file containing weightings, and the application's memory size in $MEMORY_LIMIT.
    def initialize(args)
      weight_balancing_memory_heuristic = WeightBalancingMemoryHeuristic.new(MEMORY_HEURISTICS_YAML_FILE, WEIGHTINGS_NAME, args)

      @heap = weight_balancing_memory_heuristic.output['heap']
      @permgen = weight_balancing_memory_heuristic.output['permgen']
      @stack = weight_balancing_memory_heuristic.output['stack']
    end

    private

    MEMORY_HEURISTICS_YAML_FILE = 'jres.yml'
    WEIGHTINGS_NAME = 'pre_8'

  end
end
