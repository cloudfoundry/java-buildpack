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

require 'spec_helper'
require 'java_buildpack/utils/memory_heuristics'

describe JavaBuildpack::MemoryHeuristics do

  TEST_HEAP_WEIGHTING = 0.5
  TEST_PERMGEN_WEIGHTING = 0.3
  TEST_STACK_WEIGHTING = 0.1
  TEST_NATIVE_WEIGHTING = 0.1
  TEST_SMALL_NATIVE_WEIGHTING = 0.05
  TEST_WEIGHTINGS = {'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => TEST_NATIVE_WEIGHTING}

  it 'should accept a memory limit in megabytes or gigabytes' do
    with_memory_limit('1G') do
      expect(JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS).memory_limit).to eq('1048576k')
    end
    with_memory_limit('1g') do
      expect(JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS).memory_limit).to eq('1048576k')
    end
    with_memory_limit('1M') do
      expect(JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS).memory_limit).to eq('1024k')
    end
    with_memory_limit('1m') do
      expect(JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS).memory_limit).to eq('1024k')
    end
  end

  it 'should fail if a memory limit is not specified' do
    with_memory_limit(nil) do
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/not\ specified/)
    end
  end

  it 'should fail if a memory limit does not have a unit' do
    with_memory_limit('1') do
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if a memory limit is not an number' do
    with_memory_limit('xm') do
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if a memory limit is not an integer' do
    with_memory_limit('1.1m') do
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if a memory limit is negative' do
    with_memory_limit('-1m') do
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the configured weightings sum to more than 1' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.4, 'stack' => 0.1, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the heap weighting is not configured' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'permgen' => 0.3, 'stack' => 0.1, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/not specified/)
    end
  end

  it 'should fail if the heap weighting is less than or equal to 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0, 'permgen' => 0.3, 'stack' => 0.1, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the permgen weighting is not configured' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'stack' => 0.1, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/not specified/)
    end
  end

  it 'should fail if the permgen weighting is less than or equal to 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => -0.3, 'stack' => 0.1, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the stack weighting is not configured' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.3, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/not specified/)
    end
  end

  it 'should fail if the stack weighting is less than or equal to 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.3, 'stack' => 0, 'native' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end


  it 'should fail if the native weighting is not configured' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.3, 'stack' => 0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/not specified/)
    end
  end

  it 'should fail if the native weighting is less than or equal to 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.3, 'stack' => 0.1, 'native' => -0.1})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end


  it 'should fail if a configured weighting is invalid' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => 'x'})
      expect { JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS) }.to raise_error(/Invalid/)
    end
  end

  it 'should default maximum heap size and permgen size according to the configured weightings' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS)
      expect(memory_heuristics.heap_size_maximum).to eq("#{(1024 * 1024 * TEST_HEAP_WEIGHTING).to_i.to_s}k")
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 1024 * TEST_PERMGEN_WEIGHTING).to_i.to_s}k")
    end
  end

it 'should default the stack size regardless of the memory limit' do
    with_memory_limit('0m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS)
      expect(memory_heuristics.stack_size).to eq('1024k')
    end
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when the weightings sum to less than 1' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'stack' => TEST_STACK_WEIGHTING, 'native' => TEST_SMALL_NATIVE_WEIGHTING})
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new(TEST_WEIGHTINGS)
      expect(memory_heuristics.heap_size_maximum).to eq("#{(1024 * 1024 * TEST_HEAP_WEIGHTING).to_i.to_s}k")
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 1024 * TEST_PERMGEN_WEIGHTING).to_i.to_s}k")
    end
  end

  it 'should default permgen size according to the configured weightings when maximum heap size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({'heap_size_maximum' => "#{(4096 * 3 / 4).to_i.to_s}m"})
      expect(memory_heuristics.heap_size_maximum).to eq("#{(1024 * 4096 * 3 / 4).to_i.to_s}k")
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 1024 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_STACK_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}k")
    end
  end

  it 'should default maximum heap size according to the configured weightings when maximum permgen size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({'permgen_size_maximum' => "#{(4096 / 2).to_i.to_s}m"})
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 4096 / 2).to_i.to_s}k")
      expect(memory_heuristics.heap_size_maximum).to eq("#{(1024 * 4096 * TEST_HEAP_WEIGHTING - 1024 * 4096 * 0.2 * TEST_HEAP_WEIGHTING / (TEST_HEAP_WEIGHTING + +TEST_STACK_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}k")
    end
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({'stack_size' => '2m'})
      # The stack size is double the default, so this will consume an extra 409.6m, which should be taken from heap, permgen, and native according to their weightings
      expect(memory_heuristics.heap_size_maximum).to eq("#{(1024 * 4096 * TEST_HEAP_WEIGHTING - 1024 * 409.6 * TEST_HEAP_WEIGHTING / (TEST_HEAP_WEIGHTING + TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}k")
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 409.6 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_HEAP_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}k")
    end
  end

  it 'should default permgen size according to the configured weightings when maximum heap size and thread stack size are specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({'heap_size_maximum' => "#{(4096 * 3 / 4).to_i.to_s}m", 'stack_size' => '2m'})
      # The heap size is 1G more than the default, so this should be taken from permgen according to the weightings
      # The stack size is double the default, so this will consume an extra 409.6m, some of which should be taken from permgen according to the weightings
      expect(memory_heuristics.permgen_size_maximum).to eq("#{(1024 * 4096 * TEST_PERMGEN_WEIGHTING - 1024 * 1024 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING) -
      1024 * 409.6 * TEST_PERMGEN_WEIGHTING / (TEST_PERMGEN_WEIGHTING + TEST_NATIVE_WEIGHTING)).to_i.to_s}k")
    end
  end

  it 'should not apply any defaults when maximum heap size, maximum permgen size, and thread stack size are specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return(TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({'heap_size_maximum' => '1m', 'permgen_size_maximum' => '1m', 'stack_size' => '2m'})
      expect(memory_heuristics.heap_size_maximum).to eq('1024k')
      expect(memory_heuristics.permgen_size_maximum).to eq('1024k')
      expect(memory_heuristics.stack_size).to eq('2048k')
    end
  end


  def with_memory_limit(memory_limit)
    previous_value = ENV['MEMORY_LIMIT']
    begin
      ENV['MEMORY_LIMIT'] = memory_limit
      yield
    ensure
      ENV['MEMORY_LIMIT'] = previous_value
    end
  end

end
