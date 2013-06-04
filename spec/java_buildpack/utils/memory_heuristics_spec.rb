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
  TEST_NATIVE_WEIGHTING = 0.2
  TEST_SMALL_NATIVE_WEIGHTING = 0.2

  it 'should accept a memory limit in megabytes or gigabytes' do
    with_memory_limit('1G') do
      expect(JavaBuildpack::MemoryHeuristics.new({}).memory_limit).to eq('1048576k')
    end
    with_memory_limit('1g') do
      expect(JavaBuildpack::MemoryHeuristics.new({}).memory_limit).to eq('1048576k')
    end
    with_memory_limit('1M') do
      expect(JavaBuildpack::MemoryHeuristics.new({}).memory_limit).to eq('1024k')
    end
    with_memory_limit('1m') do
      expect(JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}).memory_limit).to eq('1024k')
    end
  end

  it 'should fail if a memory limit does not have a unit' do
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1'}) }.to raise_error
  end

  it 'should fail if a memory limit is not an number' do
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => 'xm'}) }.to raise_error
  end

  it 'should fail if a memory limit is not an integer' do
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1.1m'}) }.to raise_error
  end

  it 'should fail if the configured weightings sum to more than 1' do
    YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.4, 'native' => 0.2})
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}) }.to raise_error
  end

  it 'should fail if the heap weighting is not configured' do
    YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'permgen' => 0.4, 'native' => 0.2})
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}) }.to raise_error
  end

  it 'should fail if the permgen weighting is not configured' do
    YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'native' => 0.2})
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}) }.to raise_error
  end

  it 'should fail if the native weighting is not configured' do
    YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => 0.5, 'permgen' => 0.4})
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}) }.to raise_error
  end

  it 'should fail if a configured weighting is invalid' do
    YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'native' => 'x'})
    expect { JavaBuildpack::MemoryHeuristics.new({:memory_limit => '1m'}) }.to raise_error
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is not specified' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'native' => TEST_NATIVE_WEIGHTING})
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({})
      expect(memory_heuristics.default_heap_size_maximum).to eq("#{(1024*1024*TEST_HEAP_WEIGHTING).to_i.to_s}k")
      expect(memory_heuristics.default_permgen_size).to eq("#{(1024*1024*TEST_PERMGEN_WEIGHTING).to_i.to_s}k")
    end
  end

  it 'should default maximum heap size and permgen size according to the configured weightings when thread stack size is not specified and the weightings sum to less than 1' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path 'config/memory_heuristics.yml').and_return({'heap' => TEST_HEAP_WEIGHTING, 'permgen' => TEST_PERMGEN_WEIGHTING, 'native' => TEST_SMALL_NATIVE_WEIGHTING})
      memory_heuristics = JavaBuildpack::MemoryHeuristics.new({})
      expect(memory_heuristics.default_heap_size_maximum).to eq("#{(1024*1024*TEST_HEAP_WEIGHTING).to_i.to_s}k")
      expect(memory_heuristics.default_permgen_size).to eq("#{(1024*1024*TEST_PERMGEN_WEIGHTING).to_i.to_s}k")
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
