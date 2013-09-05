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

require 'spec_helper'
require 'java_buildpack/diagnostics/common'
require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

module JavaBuildpack::Jre

  describe WeightBalancingMemoryHeuristic do

    TEST_HEAP_WEIGHTING = 0.5
    TEST_PERMGEN_WEIGHTING = 0.3
    TEST_STACK_WEIGHTING = 0.1
    TEST_NATIVE_WEIGHTING = 0.1
    TEST_SMALL_NATIVE_WEIGHTING = 0.05
    TEST_WEIGHTINGS = {
      'heap' => TEST_HEAP_WEIGHTING,
      'permgen' => TEST_PERMGEN_WEIGHTING,
      'stack' => TEST_STACK_WEIGHTING,
      'native' => TEST_NATIVE_WEIGHTING
    }

    JAVA_OPTS = {
      'heap' => '-Xmx',
      'permgen' => '-XX:MaxPermSize=',
      'stack' => '-Xss',
    }.freeze

    VALID_HEURISTICS = %w(heap permgen stack native)

    VALID_SIZES = %w(heap permgen stack)

    before do
      JavaBuildpack::Diagnostics::LoggerFactory.send :close # suppress warnings
      $stderr = StringIO.new
      File.delete(JavaBuildpack::Diagnostics.get_buildpack_log Dir.tmpdir)
      JavaBuildpack::Diagnostics::LoggerFactory.create_logger Dir.tmpdir
    end

    it 'should fail if a memory limit is negative' do
      with_memory_limit('-1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }.to raise_error(/Invalid/)
      end
    end

    it 'should fail if the configured weightings sum to more than 1' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => 0.5, 'permgen' => 0.4, 'stack' => 0.1, 'native' => 0.1 }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the heap weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => -0.1, 'permgen' => 0.3, 'stack' => 0.1, 'native' => 0.1 }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the permgen weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => 0.5, 'permgen' => -0.3, 'stack' => 0.1, 'native' => 0.1 }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the stack weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => 0.5, 'permgen' => 0.3, 'stack' => -0.1, 'native' => 0.1 }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the native weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => 0.5, 'permgen' => 0.3, 'stack' => 0.1, 'native' => -0.1 }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if a configured weighting is invalid' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({ }, { 'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => 'x' }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings' do
      with_memory_limit('1024m') do
        output = WeightBalancingMemoryHeuristic.new({ }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include("-Xmx#{(1024 * TEST_HEAP_WEIGHTING).to_i.to_s}M")
        expect(output).to include("-XX:MaxPermSize=#{(1024 * 1024 * TEST_PERMGEN_WEIGHTING).to_i.to_s}K")
      end
    end

    it 'should default the stack size regardless of the memory limit' do
      with_memory_limit('0m') do
        output = WeightBalancingMemoryHeuristic.new({ }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-Xss1M')
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings when the weightings sum to less than 1' do
      with_memory_limit('1024m') do
        output = WeightBalancingMemoryHeuristic.new({ }, { 'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => TEST_SMALL_NATIVE_WEIGHTING }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include("-Xmx#{(1024 * TEST_HEAP_WEIGHTING).to_i.to_s}M")
        expect(output).to include("-XX:MaxPermSize=#{(1024 * 1024 * TEST_PERMGEN_WEIGHTING).to_i.to_s}K")
      end
    end

    it 'should default permgen size according to the configured weightings when maximum heap size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => "#{(4096 * 3 / 4).to_i.to_s}m" }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-Xmx3G')
        expect(output).to include("-XX:MaxPermSize=#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 1024 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
      end
    end

    it 'should default maximum heap size according to the configured weightings when maximum permgen size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => "#{(4096 / 2).to_i.to_s}m" }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=2G')
        expect(output).to include("-Xmx#{(1024 * 4096 * TEST_HEAP_WEIGHTING - 1024 * 4096 * 0.2 * TEST_HEAP_WEIGHTING / (TEST_HEAP_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '2m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        # The stack size is double the default, so this will consume an extra 409.6m, which should be taken from heap, permgen, and native according to their weightings
        expect(output).to include("-Xmx#{(1024 * 4096 * TEST_HEAP_WEIGHTING - 1024 * 409.6 * TEST_HEAP_WEIGHTING / (TEST_HEAP_WEIGHTING + TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
        expect(output).to include("-XX:MaxPermSize=#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 409.6 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_HEAP_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
      end
    end

    it 'should default permgen size according to the configured weightings when maximum heap size and thread stack size are specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => "#{(4096 * 3 / 4).to_i.to_s}m", 'stack' => '2m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        # The heap size is 1G more than the default, so this should be taken from permgen according to the weightings
        # The stack size is double the default, so this will consume an extra 409.6m, some of which should be taken from permgen according to the weightings
        expect(output).to include("-XX:MaxPermSize=#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 1024 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING) -
                                                      1024 * 409.6 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
      end
    end

    it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-Xmx1M')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should work correctly with a single memory type' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ }, { 'heap' => TEST_HEAP_WEIGHTING }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-Xmx2G')
      end
    end

    it 'should work correctly with no memory types' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ }, { }, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to eq([])
      end
    end

    it 'should issue a warning when the specified maximum memory sizes imply the total memory size may be too large' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(output).to include('-Xmx1M')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
        expect(buildpack_log_contents).to match(/WARN/)
      end
    end

    it 'should issue a warning when the specified stack size is close to the default' do
      with_memory_limit('4096m') do
        WeightBalancingMemoryHeuristic.new({ 'stack' => '1025k' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(buildpack_log_contents).to match(/WARN.*is close to the default/)
      end
    end

    it 'should issue a warning when the specified maximum heap size is close to the default' do
      with_memory_limit('4096m') do
        WeightBalancingMemoryHeuristic.new({ 'heap' => '2049m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(buildpack_log_contents).to match(/WARN.*is close to the default/)
      end
    end

    it 'should issue a warning when the specified maximum permgen size is close to the default' do
      with_memory_limit('4096m') do
        WeightBalancingMemoryHeuristic.new({ 'permgen' => '1339m' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(buildpack_log_contents).to match(/WARN.*is close to the default/)
      end
    end

    it 'should not issue a warning when the specified maximum permgen size is not close to the default' do
      with_memory_limit('1G') do
        WeightBalancingMemoryHeuristic.new({ 'permgen' => '128M' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        expect(buildpack_log_contents).not_to match(/WARN.*is close to the default/)
      end
    end

    it 'should fail when the specified maximum memory is larger than the total memory size' do
      with_memory_limit('4096m') do
        expect { WeightBalancingMemoryHeuristic.new({ 'heap' => '5g' }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve }.to raise_error(/exceeded/)
      end
    end

    it 'should only default the stack size when the total memory size is not available' do
      with_memory_limit(nil) do
        output = WeightBalancingMemoryHeuristic.new({ }, TEST_WEIGHTINGS, VALID_SIZES, VALID_HEURISTICS, JAVA_OPTS).resolve
        output.should_not include(/-Xmx/)
        output.should_not include(/-XX:MaxPermSize=/)
        expect(output).to include('-Xss1M')
      end
    end

    def with_memory_limit(memory_limit)
      previous_value, ENV['MEMORY_LIMIT'] = ENV['MEMORY_LIMIT'], memory_limit
      yield
    ensure
      ENV['MEMORY_LIMIT'] = previous_value
    end

    def buildpack_log_contents
      File.read(JavaBuildpack::Diagnostics.get_buildpack_log(Dir.tmpdir))
    end

  end

end
