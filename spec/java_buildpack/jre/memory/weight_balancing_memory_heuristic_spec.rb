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
require 'logging_helper'
require 'memory_limit_helper'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

describe JavaBuildpack::Jre::WeightBalancingMemoryHeuristic do
  include_context 'logging_helper'
  include_context 'memory_limit_helper'

  let(:heuristic) do |example|
    sizes       = example.metadata[:sizes] || {}
    weightings  = example.metadata[:weightings] || { 'heap' => 5, 'permgen' => 3, 'stack' => 1, 'native' => 1 }
    valid_types = %w(heap permgen stack native)
    java_opts   = { 'heap'  => ->(v) { "-Xmx#{v}" }, 'permgen' => ->(v) { "-XX:MaxPermSize=#{v}" },
                    'stack' => ->(v) { "-Xss#{v}" } }

    JavaBuildpack::Jre::WeightBalancingMemoryHeuristic.new(sizes, weightings, valid_types, java_opts)
  end

  it 'should fail if a memory limit is negative',
     memory_limit: '-1m' do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should fail if the heap weighting is less than 0',
     with_memory_limit: '1m',
     weightings:        { 'heap' => -1 } do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should fail if the permgen weighting is less than 0',
     memory_limit: '1m',
     weightings:   { 'permgen' => -1 } do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should fail if the stack weighting is less than 0',
     memory_limit: '1m',
     weightings:   { 'stack' => -1 } do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should fail if the native weighting is less than 0',
     memory_limit: '1m',
     weightings:   { 'native' => -1 } do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should fail if a configured weighting is invalid',
     memory_limit: '1m',
     weightings:   { 'native' => 'x' } do

    expect { heuristic.resolve }.to raise_error /Invalid/
  end

  it 'should default maximum heap size and permgen size according to the configured weightings',
     memory_limit: '1024m' do

    output = heuristic.resolve

    expect(output).to include('-Xmx512M')
    expect(output).to include('-XX:MaxPermSize=314572K')
  end

  it 'should default the stack size even with a small memory limit',
     memory_limit: '10m' do

    output = heuristic.resolve

    expect(output).to include('-Xss1M')
  end

  it 'should default permgen size according to the configured weightings when maximum heap size is specified',
     memory_limit: '4096m',
     sizes:        { 'stack' => '1m', 'heap' => "#{(4096 * 3 / 4).to_i.to_s}m" } do

    output = heuristic.resolve

    expect(output).to include('-Xmx3G')
    expect(output).to include('-XX:MaxPermSize=471859K')
  end

  it 'should default maximum heap size according to the configured weightings when maximum permgen size is specified',
     memory_limit: '4096m',
     sizes:        { 'stack' => '1m', 'permgen' => '2g' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=2G')
    expect(output).to include('-Xmx1398101K')
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified',
     memory_limit: '4096m',
     sizes:        { 'stack' => '2m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx2G')
    expect(output).to include('-XX:MaxPermSize=1258291K')
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified as a range',
     memory_limit: '4096m',
     sizes:        { 'stack' => '2m..3m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx2G')
    expect(output).to include('-XX:MaxPermSize=1258291K')
    expect(output).to include('-Xss2M')
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified as a range which impinges on heap and permgen',
     memory_limit: '4096m',
     sizes:        { 'stack' => '1g..2g' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx1747626K')
    expect(output).to include('-XX:MaxPermSize=1G')
    expect(output).to include('-Xss1G')
  end

  it 'should default stack size to the top of its range when heap size and permgen size allow for excess memory',
     memory_limit: '4096m',
     sizes:        { 'heap' => '50m', 'permgen' => '50m', 'stack' => '400m..500m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx50M')
    expect(output).to include('-XX:MaxPermSize=50M')
    expect(output).to include('-Xss500M')
  end

  it 'should default stack size strictly within its range when heap size and permgen size allow for just enough excess memory',
     memory_limit: '4096m',
     sizes:        { 'heap' => '3000m', 'permgen' => '196m', 'stack' => '400m..500m' } do

    output = heuristic.resolve

    expect(output).to include('-Xss450000K')
  end

  it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified',
     memory_limit: '4096m',
     sizes:        { 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx1M')
    expect(output).to include('-XX:MaxPermSize=1M')
    expect(output).to include('-Xss2M')
  end

  it 'should work correctly with a single memory type',
     memory_limit: '4096m',
     weightings:   { 'heap' => 5 } do

    output = heuristic.resolve

    expect(output).to include('-Xmx4G')
  end

  it 'should work correctly with no memory types',
     memory_limit: '4096m',
     weightings:   {} do

    output = heuristic.resolve

    expect(output).to eq([])
  end

  it 'should issue a warning when the specified maximum memory sizes imply the total memory size may be too large',
     memory_limit: '4096m',
     sizes:        { 'heap' => '800m', 'permgen' => '800m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx800M')
    expect(output).to include('-XX:MaxPermSize=800M')
    expect(log_contents).to match /There is more than .* times more spare native memory than the default/
  end

  it 'should issue a warning when the specified maximum memory sizes, including native, imply the total memory size may be too large',
     memory_limit: '4096m',
     sizes:        { 'heap' => '1m', 'permgen' => '1m', 'stack' => '2m', 'native' => '2000m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx1M')
    expect(output).to include('-XX:MaxPermSize=1M')
    expect(output).to include('-Xss2M')
    expect(log_contents).to match /allocated Java memory sizes total .* which is less than/
  end

  it 'should allow native memory to be fixed',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '1m', 'stack' => '2m', 'native' => '10m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx3763609K')
    expect(output).to include('-XX:MaxPermSize=1M')
    expect(output).to include('-Xss2M')
  end

  it 'should allow native memory to be specified as a range with an upper bound',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '1m', 'stack' => '2m', 'native' => '10m..20m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx3753369K')
    expect(output).to include('-XX:MaxPermSize=1M')
    expect(output).to include('-Xss2M')
  end

  it 'should issue a warning when the specified maximum heap size is close to the default',
     memory_limit: '4096m',
     sizes:        { 'heap' => '2049m' } do

    heuristic.resolve

    expect(log_contents).to match /WARN.*is close to the default/
  end

  it 'should issue a warning when the specified maximum permgen size is close to the default',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '1339m' } do

    heuristic.resolve

    expect(log_contents).to match /WARN.*is close to the default/
  end

  it 'should not issue a warning when the specified maximum permgen size is not close to the default',
     memory_limit: '1G',
     sizes:        { 'permgen' => '128M' } do

    heuristic.resolve

    expect(log_contents).not_to match /WARN.*is close to the default/
  end

  it 'should fail when the specified maximum memory is larger than the total memory size',
     memory_limit: '4096m',
     sizes:        { 'heap' => '5g' } do

    expect { heuristic.resolve }.to raise_error /exceeded/
  end

  it 'should default nothing when the total memory size is not available',
     with_memory_limit: nil do

    output = heuristic.resolve

    expect(output).to eq([])
  end

  it 'should use the calculated default when this falls within a specified range',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '1g..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1258291K')
  end

  it 'should use the upper bound of a range when the calculated default exceeds the upper bound of the range',
     memory_limit: '5120m',
     sizes:        { 'permgen' => '1g..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1250M')
  end

  it 'should use the lower bound of a range when the calculated default is smaller than the lower bound of the range',
     memory_limit: '2048m',
     sizes:        { 'permgen' => '1g..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1G')
  end

  it 'should use the calculated default when this exceeds the lower bound of a specified open range',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '1g..' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1258291K')
  end

  it 'should use the lower bound of an open range when the calculated default is smaller than the lower bound of the range',
     memory_limit: '2048m',
     sizes:        { 'permgen' => '1g..' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1G')
  end

  it 'should use the calculated default when this falls below the upper bound of an open range',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1258291K')
  end

  it 'should use the upper bound of an open range when the calculated default exceeds the upper bound of the range',
     memory_limit: '5120m',
     sizes:        { 'permgen' => '..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1250M')
  end

  it 'should an open range with no lower or upper bound',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '..' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1258291K')
  end

  it 'should allow a zero lower bound to be specified without units',
     memory_limit: '5120m',
     sizes:        { 'permgen' => '0..1250m' } do

    output = heuristic.resolve

    expect(output).to include('-XX:MaxPermSize=1250M')
  end

  it 'should fail if a range is empty',
     memory_limit: '4096m',
     sizes:        { 'permgen' => '2m..1m' } do

    expect { heuristic.resolve }.to raise_error /Invalid range/
  end

  it 'should default maximum heap size and permgen size according to the configured weightings and range lower bounds',
     memory_limit: '1024m',
     sizes:        { 'stack' => '1m', 'permgen' => '400m..500m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx445098K')
    expect(output).to include('-XX:MaxPermSize=400M')
  end

  it 'should default maximum heap size and permgen size according to the configured weightings and range upper bounds',
     memory_limit: '1024m',
     sizes:        { 'stack' => '1m', 'permgen' => '100m..285m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx543232K')
    expect(output).to include('-XX:MaxPermSize=285M')
  end

  it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified as tight ranges',
     memory_limit: '4096m',
     sizes:        { 'heap' => '1m..1024k', 'permgen' => '1024k..1m', 'stack' => '2m..2m' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx1M')
    expect(output).to include('-XX:MaxPermSize=1M')
    expect(output).to include('-Xss2M')
  end

  it 'should allow native memory to be specified with no upper bound',
     memory_limit: '5120m',
     sizes:        { 'stack' => '1m..1m', 'native' => '4000m..' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx380M')
    expect(output).to include('-XX:MaxPermSize=228M')
    expect(output).to include('-Xss1M')
  end

  it 'should respect lower bounds when there is no memory limit',
     memory_limit: nil,
     sizes:        { 'heap' => '30m..', 'permgen' => '10m', 'stack' => '1m..1m', 'native' => '10m..' } do

    output = heuristic.resolve

    expect(output).to include('-Xmx30M')
    expect(output).to include('-XX:MaxPermSize=10M')
    expect(output).to include('-Xss1M')
  end

  it 'should work correctly with other weightings',
     memory_limit: '256m',
     weightings:   { 'heap' => 75, 'permgen' => 10, 'stack' => 5, 'native' => 10 } do

    output = heuristic.resolve

    expect(output).to include('-Xmx192M')
    expect(output).to include('-XX:MaxPermSize=26214K')
    expect(output).to include('-Xss1M')
  end

end
