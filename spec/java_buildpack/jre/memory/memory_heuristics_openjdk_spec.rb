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
require 'java_buildpack/jre/memory/memory_heuristics_openjdk'

def heuristics_post8(hash)
  {'openjdk' => {'memory_heuristics' => {'post_8' => hash}}}
end

describe JavaBuildpack::Jre::MemoryHeuristicsOpenJDK do

  OPENJDK_TEST_HEAP_WEIGHTING = 0.5
  OPENJDK_TEST_METASPACE_WEIGHTING = 0.3
  OPENJDK_TEST_STACK_WEIGHTING = 0.1
  OPENJDK_TEST_NATIVE_WEIGHTING = 0.1
  OPENJDK_TEST_SMALL_NATIVE_WEIGHTING = 0.05
  OPENJDK_TEST_WEIGHTINGS = heuristics_post8({'heap' => OPENJDK_TEST_HEAP_WEIGHTING, 'metaspace' => OPENJDK_TEST_METASPACE_WEIGHTING, 'stack' => OPENJDK_TEST_STACK_WEIGHTING, 'native' => OPENJDK_TEST_NATIVE_WEIGHTING})
  OPENJDK_CONFIG_FILE_PATH = 'config/jres.yml'

  before do
    $stderr = StringIO.new
  end

  it 'should fail if the configured weightings sum to more than 1' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => 0.5, 'metaspace' => 0.4, 'stack' => 0.1, 'native' => 0.1}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the heap weighting is less than 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => -0.1, 'metaspace' => 0.3,
                                                                                                   'stack' => 0.1, 'native' => 0.1}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the metaspace weighting is less than 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => 0.5, 'metaspace' => -0.3, 'stack' => 0.1, 'native' => 0.1}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the stack weighting is less than 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => 0.5, 'metaspace' => 0.3,
                                                                                                   'stack' => -0.1, 'native' => 0.1}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if the native weighting is less than 0' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => 0.5, 'metaspace' => 0.3, 'stack' => 0.1, 'native' => -0.1}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should fail if a configured weighting is invalid' do
    with_memory_limit('1m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => OPENJDK_TEST_HEAP_WEIGHTING, 'metaspace' => OPENJDK_TEST_METASPACE_WEIGHTING, 'stack' => OPENJDK_TEST_STACK_WEIGHTING, 'native' => 'x'}))
      expect { JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({}) }.to raise_error(/Invalid/)
    end
  end

  it 'should default maximum heap size and metaspace size according to the configured weightings' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({})
      expect(memory_heuristics.output['heap']).to eq("#{(1024 * OPENJDK_TEST_HEAP_WEIGHTING).to_i.to_s}M")
      expect(memory_heuristics.output['metaspace']).to eq("#{(1024 * 1024 * OPENJDK_TEST_METASPACE_WEIGHTING).to_i.to_s}K")
    end
  end

  it 'should default the stack size regardless of the memory limit' do
    with_memory_limit('0m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({})
      expect(memory_heuristics.output['stack']).to eq('1M')
    end
  end

  it 'should default maximum heap size and metaspace size according to the configured weightings when the weightings sum to less than 1' do
    with_memory_limit('1024m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(heuristics_post8({'heap' => OPENJDK_TEST_HEAP_WEIGHTING, 'metaspace' => OPENJDK_TEST_METASPACE_WEIGHTING, 'stack' => OPENJDK_TEST_STACK_WEIGHTING, 'native' => OPENJDK_TEST_SMALL_NATIVE_WEIGHTING}))
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({})
      expect(memory_heuristics.output['heap']).to eq("#{(1024 * OPENJDK_TEST_HEAP_WEIGHTING).to_i.to_s}M")
      expect(memory_heuristics.output['metaspace']).to eq("#{(1024 * 1024 * OPENJDK_TEST_METASPACE_WEIGHTING).to_i.to_s}K")
    end
  end

  it 'should default metaspace size according to the configured weightings when maximum heap size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({'heap' => "#{(4096 * 3 / 4).to_i.to_s}m"})
      expect(memory_heuristics.output['heap']).to eq("3G")
      expect(memory_heuristics.output['metaspace']).to eq("#{(1024 * 4096 * OPENJDK_TEST_METASPACE_WEIGHTING - 1024 * 1024 * OPENJDK_TEST_METASPACE_WEIGHTING / (OPENJDK_TEST_METASPACE_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
    end
  end

  it 'should default maximum heap size according to the configured weightings when maximum metaspace size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({'metaspace' => "#{(4096 / 2).to_i.to_s}m"})
      expect(memory_heuristics.output['metaspace']).to eq("2G")
      expect(memory_heuristics.output['heap']).to eq("#{(1024 * 4096 * OPENJDK_TEST_HEAP_WEIGHTING - 1024 * 4096 * 0.2 * OPENJDK_TEST_HEAP_WEIGHTING / (OPENJDK_TEST_HEAP_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
    end
  end

  it 'should default maximum heap size and metaspace size according to the configured weightings when thread stack size is specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({'stack' => '2m'})
      # The stack size is double the default, so this will consume an extra 409.6m, which should be taken from heap, metaspace, and native according to their weightings
      expect(memory_heuristics.output['heap']).to eq("#{(1024 * 4096 * OPENJDK_TEST_HEAP_WEIGHTING - 1024 * 409.6 * OPENJDK_TEST_HEAP_WEIGHTING / (OPENJDK_TEST_HEAP_WEIGHTING + OPENJDK_TEST_METASPACE_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
      expect(memory_heuristics.output['metaspace']).to eq("#{(1024 * 4096 * OPENJDK_TEST_METASPACE_WEIGHTING - 1024 * 409.6 * OPENJDK_TEST_METASPACE_WEIGHTING / (OPENJDK_TEST_METASPACE_WEIGHTING + OPENJDK_TEST_HEAP_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
    end
  end

  it 'should default metaspace size according to the configured weightings when maximum heap size and thread stack size are specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({'heap' => "#{(4096 * 3 / 4).to_i.to_s}m", 'stack' => '2m'})
      # The heap size is 1G more than the default, so this should be taken from metaspace according to the weightings
      # The stack size is double the default, so this will consume an extra 409.6m, some of which should be taken from metaspace according to the weightings
      expect(memory_heuristics.output['metaspace']).to eq("#{(1024 * 4096 * OPENJDK_TEST_METASPACE_WEIGHTING - 1024 * 1024 * OPENJDK_TEST_METASPACE_WEIGHTING / (OPENJDK_TEST_METASPACE_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING) -
          1024 * 409.6 * OPENJDK_TEST_METASPACE_WEIGHTING / (OPENJDK_TEST_METASPACE_WEIGHTING + OPENJDK_TEST_NATIVE_WEIGHTING)).to_i.to_s}K")
    end
  end

  it 'should not apply any defaults when maximum heap size, maximum metaspace size, and thread stack size are specified' do
    with_memory_limit('4096m') do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({'heap' => '1m', 'metaspace' => '1m', 'stack' => '2m'})
      expect(memory_heuristics.output['heap']).to eq('1M')
      expect(memory_heuristics.output['metaspace']).to eq('1M')
      expect(memory_heuristics.output['stack']).to eq('2M')
    end
  end

  it 'should only defaults the thread stack size when the memory limit is unknown' do
    with_memory_limit(nil) do
      YAML.stub(:load_file).with(File.expand_path OPENJDK_CONFIG_FILE_PATH).and_return(OPENJDK_TEST_WEIGHTINGS)
      memory_heuristics = JavaBuildpack::Jre::MemoryHeuristicsOpenJDK.new({})
      expect(memory_heuristics.output['heap']).to be_nil
      expect(memory_heuristics.output['metaspace']).to be_nil
      expect(memory_heuristics.output['stack']).to eq('1M')
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
