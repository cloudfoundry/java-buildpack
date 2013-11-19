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

    TEST_HEAP_WEIGHTING = 5
    TEST_PERMGEN_WEIGHTING = 3
    TEST_STACK_WEIGHTING = 1
    TEST_NATIVE_WEIGHTING = 1
    TEST_WEIGHTINGS = {
        'heap' => TEST_HEAP_WEIGHTING,
        'permgen' => TEST_PERMGEN_WEIGHTING,
        'stack' => TEST_STACK_WEIGHTING,
        'native' => TEST_NATIVE_WEIGHTING
    }

    PRE8_JAVA_OPTS = {
        'heap' => ->(v) { "-Xmx#{v}" },
        'permgen' => ->(v) { "-XX:MaxPermSize=#{v}" },
        'stack' => ->(v) { "-Xss#{v}" }
    }.freeze

    PRE8_VALID_TYPES = %w(heap permgen stack native)

    before do
      JavaBuildpack::Diagnostics::LoggerFactory.send :close # suppress warnings
      $stderr = StringIO.new
      File.delete(JavaBuildpack::Diagnostics.get_buildpack_log Dir.tmpdir)
      JavaBuildpack::Diagnostics::LoggerFactory.create_logger Dir.tmpdir
    end

    it 'should fail if a memory limit is negative' do
      with_memory_limit('-1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, {}, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }.to raise_error(/Invalid/)
      end
    end

    it 'should fail if the heap weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, { 'heap' => -0.1, 'permgen' => 0.3, 'stack' => 0.1, 'native' => 0.1 }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the permgen weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, { 'heap' => 0.5, 'permgen' => -0.3, 'stack' => 0.1, 'native' => 0.1 }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the stack weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, { 'heap' => 0.5, 'permgen' => 0.3, 'stack' => -0.1, 'native' => 0.1 }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if the native weighting is less than 0' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, { 'heap' => 0.5, 'permgen' => 0.3, 'stack' => 0.1, 'native' => -0.1 }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should fail if a configured weighting is invalid' do
      with_memory_limit('1m') do
        expect { WeightBalancingMemoryHeuristic.new({}, { 'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => 'x' }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }
        .to raise_error(/Invalid/)
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings' do
      with_memory_limit('1024m') do
        output = WeightBalancingMemoryHeuristic.new({}, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx512M')
        expect(output).to include('-XX:MaxPermSize=314572K')
      end
    end

    it 'should default the stack size even with a small memory limit' do
      with_memory_limit('10m') do
        output = WeightBalancingMemoryHeuristic.new({}, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xss1M')
      end
    end

    it 'should default permgen size according to the configured weightings when maximum heap size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1m', 'heap' => "#{(4096 * 3 / 4).to_i.to_s}m" }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx3G')
        expect(output).to include('-XX:MaxPermSize=471859K')
      end
    end

    it 'should default maximum heap size according to the configured weightings when maximum permgen size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1m', 'permgen' => '2g' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=2G')
        expect(output).to include('-Xmx1398101K')
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '2m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx2G')
        expect(output).to include('-XX:MaxPermSize=1258291K')
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified as a range' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '2m..3m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx2G')
        expect(output).to include('-XX:MaxPermSize=1258291K')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified as a range which impinges on heap and permgen' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1g..2g' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx1747626K')
        expect(output).to include('-XX:MaxPermSize=1G')
        expect(output).to include('-Xss1G')
      end
    end

    it 'should default stack size to the top of its range when heap size and permgen size allow for excess memory' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '50m', 'permgen' => '50m', 'stack' => '400m..500m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx50M')
        expect(output).to include('-XX:MaxPermSize=50M')
        expect(output).to include('-Xss500M')
      end
    end

    it 'should default stack size strictly within its range when heap size and permgen size allow for just enough excess memory' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '3000m', 'permgen' => '196m', 'stack' => '400m..500m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xss450000K')
      end
    end

    it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx1M')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should work correctly with a single memory type' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({}, { 'heap' => TEST_HEAP_WEIGHTING }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx4G')
      end
    end

    it 'should work correctly with no memory types' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({}, {}, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to eq([])
      end
    end

    it 'should issue a warning when the specified maximum memory sizes imply the total memory size may be too large' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '800m', 'permgen' => '800m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx800M')
        expect(output).to include('-XX:MaxPermSize=800M')
        expect(buildpack_log_contents).to match(/There is more than .* times more spare native memory than the default/)
      end
    end

    it 'should issue a warning when the specified maximum memory sizes, including native, imply the total memory size may be too large' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m', 'native' => '2000m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx1M')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
        expect(buildpack_log_contents).to match(/allocated Java memory sizes total .* which is less than/)
      end
    end

    it 'should allow native memory to be fixed' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1m', 'stack' => '2m', 'native' => '10m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx3763609K')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should allow native memory to be specified as a range with an upper bound' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1m', 'stack' => '2m', 'native' => '10m..20m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx3753369K')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should issue a warning when the specified maximum heap size is close to the default' do
      with_memory_limit('4096m') do
        WeightBalancingMemoryHeuristic.new({ 'heap' => '2049m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(buildpack_log_contents).to match(/WARN.*is close to the default/)
      end
    end

    it 'should issue a warning when the specified maximum permgen size is close to the default' do
      with_memory_limit('4096m') do
        WeightBalancingMemoryHeuristic.new({ 'permgen' => '1339m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(buildpack_log_contents).to match(/WARN.*is close to the default/)
      end
    end

    it 'should not issue a warning when the specified maximum permgen size is not close to the default' do
      with_memory_limit('1G') do
        WeightBalancingMemoryHeuristic.new({ 'permgen' => '128M' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(buildpack_log_contents).not_to match(/WARN.*is close to the default/)
      end
    end

    it 'should fail when the specified maximum memory is larger than the total memory size' do
      with_memory_limit('4096m') do
        expect { WeightBalancingMemoryHeuristic.new({ 'heap' => '5g' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }.to raise_error(/exceeded/)
      end
    end

    it 'should default nothing when the total memory size is not available' do
      with_memory_limit(nil) do
        output = WeightBalancingMemoryHeuristic.new({}, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to eq([])
      end
    end

    it 'should use the calculated default when this falls within a specified range' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1g..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1258291K')
      end
    end

    it 'should use the upper bound of a range when the calculated default exceeds the upper bound of the range' do
      with_memory_limit('5120m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1g..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1250M')
      end
    end

    it 'should use the lower bound of a range when the calculated default is smaller than the lower bound of the range' do
      with_memory_limit('2048m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1g..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1G')
      end
    end

    it 'should use the calculated default when this exceeds the lower bound of a specified open range' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1g..' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1258291K')
      end
    end

    it 'should use the lower bound of an open range when the calculated default is smaller than the lower bound of the range' do
      with_memory_limit('2048m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '1g..' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1G')
      end
    end

    it 'should use the calculated default when this falls below the upper bound of an open range' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1258291K')
      end
    end

    it 'should use the upper bound of an open range when the calculated default exceeds the upper bound of the range' do
      with_memory_limit('5120m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1250M')
      end
    end

    it 'should an open range with no lower or upper bound' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '..' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1258291K')
      end
    end

    it 'should allow a zero lower bound to be specified without units' do
      with_memory_limit('5120m') do
        output = WeightBalancingMemoryHeuristic.new({ 'permgen' => '0..1250m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-XX:MaxPermSize=1250M')
      end
    end

    it 'should fail if a range is empty' do
      with_memory_limit('4096m') do
        expect { WeightBalancingMemoryHeuristic.new({ 'permgen' => '2m..1m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve }.to raise_error(/Invalid range/)
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings and range lower bounds' do
      with_memory_limit('1024m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1m', 'permgen' => '400m..500m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx445098K')
        expect(output).to include('-XX:MaxPermSize=400M')
      end
    end

    it 'should default maximum heap size and permgen size according to the configured weightings and range upper bounds' do
      with_memory_limit('1024m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1m', 'permgen' => '100m..285m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx543232K')
        expect(output).to include('-XX:MaxPermSize=285M')
      end
    end

    it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified as tight ranges' do
      with_memory_limit('4096m') do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '1m..1024k', 'permgen' => '1024k..1m', 'stack' => '2m..2m' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx1M')
        expect(output).to include('-XX:MaxPermSize=1M')
        expect(output).to include('-Xss2M')
      end
    end

    it 'should allow native memory to be specified with no upper bound' do
      with_memory_limit('5120m') do
        output = WeightBalancingMemoryHeuristic.new({ 'stack' => '1m..1m', 'native' => '4000m..' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx380M')
        expect(output).to include('-XX:MaxPermSize=228M')
        expect(output).to include('-Xss1M')
      end
    end

    it 'should respect lower bounds when there is no memory limit' do
      with_memory_limit(nil) do
        output = WeightBalancingMemoryHeuristic.new({ 'heap' => '30m..', 'permgen' => '10m', 'stack' => '1m..1m', 'native' => '10m..' }, TEST_WEIGHTINGS, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx30M')
        expect(output).to include('-XX:MaxPermSize=10M')
        expect(output).to include('-Xss1M')
      end
    end

    it 'should work correctly with other weightings' do
      with_memory_limit('256m') do
        output = WeightBalancingMemoryHeuristic.new({}, { 'heap' => 75, 'permgen' => 10, 'stack' => 5, 'native' => 10 }, PRE8_VALID_TYPES, PRE8_JAVA_OPTS).resolve
        expect(output).to include('-Xmx192M')
        expect(output).to include('-XX:MaxPermSize=26214K')
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
