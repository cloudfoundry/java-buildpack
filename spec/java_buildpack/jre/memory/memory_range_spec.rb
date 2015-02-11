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

require 'spec_helper'
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'

describe JavaBuildpack::Jre::MemoryRange do

  let(:low) { JavaBuildpack::Jre::MemorySize.new('1m') }

  let(:mid) { JavaBuildpack::Jre::MemorySize.new('4m') }

  let(:test_lower_bound) { JavaBuildpack::Jre::MemorySize.new('3m') }

  let(:test_upper_bound) { JavaBuildpack::Jre::MemorySize.new('5m') }

  it 'accepts an absolute memory size and produce the corresponding tight range' do
    range = described_class.new('3m')
    expect(range.floor).to eq(test_lower_bound)
    expect(range.ceiling).to eq(test_lower_bound)
  end

  it 'accepts a range with specified lower and upper bounds' do
    range = described_class.new('3m..5m')
    expect(range.floor).to eq(test_lower_bound)
    expect(range.ceiling).to eq(test_upper_bound)
  end

  it 'accepts a range with specified lower bound, but no upper bound' do
    range = described_class.new('3m..')
    expect(range.floor).to eq(test_lower_bound)
    expect(range.bounded?).not_to be
    expect(range.ceiling).to be_nil
  end

  it 'accepts a range with specified upper bound, but no lower bound' do
    range = described_class.new('..5m')
    expect(range.floor).to eq(0)
    expect(range.ceiling).to eq(test_upper_bound)
  end

  it 'accepts a range with no lower or upper bounds' do
    range = described_class.new('..')
    expect(range.floor).to eq(0)
    expect(range.bounded?).not_to be
    expect(range.ceiling).to be_nil
  end

  it 'detects a memory size lower than a range to lie outside the range' do
    range = described_class.new('3m..5m')
    expect(range.contains?(0)).to eq(false)
  end

  it 'detects a memory size higher than a range to lie outside the range' do
    range = described_class.new('3m..5m')
    expect(range.contains?(test_upper_bound * 2)).to eq(false)
  end

  it 'detects a memory size within a range as lying inside the range' do
    range = described_class.new('3m..5m')
    expect(range.contains?(mid)).to eq(true)
  end

  it 'constrains a memory size lower than a range to the lower bound of the range' do
    range = described_class.new('3m..5m')
    expect(range.constrain(low)).to eq(test_lower_bound)
  end

  it 'constrains a memory size higher than a range to the upper bound of the range' do
    range = described_class.new('3m..5m')
    expect(range.constrain(test_upper_bound * 2)).to eq(test_upper_bound)
  end

  it 'constrains a memory size within the range to be the memory size itself' do
    range = described_class.new('3m..5m')
    expect(range.constrain(mid)).to eq(mid)
  end

  it 'detects a degenerate range' do
    range = described_class.new('3m..3m')
    expect(range.degenerate?).to eq(true)
  end

  it 'detects a non-degenerate range' do
    range = described_class.new('3m..5m')
    expect(range.degenerate?).to eq(false)
  end

  it 'fails if the range string is empty' do
    expect { described_class.new('2m..1m') }.to raise_error(/Invalid range/)
  end

  it 'fails if the range is empty' do
    expect { described_class.new(test_upper_bound, test_lower_bound) }.to raise_error(/Invalid range/)
  end

  it 'fails if the lower bound is not a MemorySize' do
    expect { described_class.new('', test_upper_bound) }.to raise_error(/Invalid combination of parameter types/)
  end

  it 'fails if the upper bound is not a MemorySize' do
    expect { described_class.new(test_lower_bound, '') }.to raise_error(/Invalid MemorySize parameter of type/)
  end

  it 'accepts valid lower and upper bounds' do
    range = described_class.new(test_lower_bound, test_upper_bound)
    expect(range.floor).to eq(test_lower_bound)
    expect(range.ceiling).to eq(test_upper_bound)
    expect(range.bounded?).to be
  end

  it 'accepts a lower bound and no upper bound' do
    range = described_class.new(test_lower_bound)
    expect(range.floor).to eq(test_lower_bound)
    expect(range.ceiling).to be_nil
    expect(range.bounded?).not_to be
  end

  it 'detects a degenerate range constructed from MemorySizes' do
    range = described_class.new(test_lower_bound, test_lower_bound)
    expect(range.degenerate?).to eq(true)
  end

  it 'detects a non-degenerate range constructed from MemorySizes' do
    range = described_class.new(test_lower_bound, test_upper_bound)
    expect(range.degenerate?).to eq(false)
  end

  it 'produces a string representation' do
    range = described_class.new('3m..5m')
    expect(range.to_s).to eq('3M..5M')
  end

  it 'supports multiplication by a numeric' do
    range = described_class.new('3m..5m')
    expect(range * 2).to eq(described_class.new('6m..10m'))
  end

  it 'compares bounded ranges for equality' do
    expect(described_class.new('3m..5m')).to eq(described_class.new(test_lower_bound, test_upper_bound))
  end

  it 'compares unbounded ranges for equality' do
    expect(described_class.new('3m..')).to eq(described_class.new(test_lower_bound))
  end

end
