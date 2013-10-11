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
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack::Jre

  describe MemoryRange do

    TEST_LOWER_BOUND = MemorySize.new('3m')
    TEST_UPPER_BOUND = MemorySize.new('5m')
    LOW = MemorySize.new('1m')
    TEST_MID = MemorySize.new('4m')

    it 'should accept an absolute memory size and produce the corresponding tight range' do
      range = MemoryRange.new('3m')
      expect(range.floor).to eq(TEST_LOWER_BOUND)
      expect(range.ceiling).to eq(TEST_LOWER_BOUND)
    end

    it 'should accept a range with specified lower and upper bounds' do
      range = MemoryRange.new('3m..5m')
      expect(range.floor).to eq(TEST_LOWER_BOUND)
      expect(range.ceiling).to eq(TEST_UPPER_BOUND)
    end

    it 'should accept a range with specified lower bound, but no upper bound' do
      range = MemoryRange.new('3m..')
      expect(range.floor).to eq(TEST_LOWER_BOUND)
      expect(range.bounded?).to be(false)
      expect(range.ceiling).to be_nil
    end

    it 'should accept a range with specified upper bound, but no lower bound' do
      range = MemoryRange.new('..5m')
      expect(range.floor).to eq(0)
      expect(range.ceiling).to eq(TEST_UPPER_BOUND)
    end

    it 'should accept a range with no lower or upper bounds' do
      range = MemoryRange.new('..')
      expect(range.floor).to eq(0)
      expect(range.bounded?).to be(false)
      expect(range.ceiling).to be_nil
    end

    it 'should detect a memory size lower than a range to lie outside the range' do
      range = MemoryRange.new('3m..5m')
      expect(range.contains?(0)).to eq(false)
    end

    it 'should detect a memory size higher than a range to lie outside the range' do
      range = MemoryRange.new('3m..5m')
      expect(range.contains?(TEST_UPPER_BOUND * 2)).to eq(false)
    end

    it 'should detect a memory size within a range as lying inside the range' do
      range = MemoryRange.new('3m..5m')
      expect(range.contains?(TEST_MID)).to eq(true)
    end

    it 'should constrain a memory size lower than a range to the lower bound of the range' do
      range = MemoryRange.new('3m..5m')
      expect(range.constrain(LOW)).to eq(TEST_LOWER_BOUND)
    end

    it 'should constrain a memory size higher than a range to the upper bound of the range' do
      range = MemoryRange.new('3m..5m')
      expect(range.constrain(TEST_UPPER_BOUND * 2)).to eq(TEST_UPPER_BOUND)
    end

    it 'should constrain a memory size within the range to be the memory size itself' do
      range = MemoryRange.new('3m..5m')
      expect(range.constrain(TEST_MID)).to eq(TEST_MID)
    end

    it 'should correctly detect a degenerate range' do
      range = MemoryRange.new('3m..3m')
      expect(range.degenerate?).to eq(true)
    end

    it 'should correctly detect a non-degenerate range' do
      range = MemoryRange.new('3m..5m')
      expect(range.degenerate?).to eq(false)
    end

    it 'should fail if the range string is empty' do
      expect { MemoryRange.new('2m..1m') }.to raise_error(/Invalid range/)
    end

    it 'should fail if the range is empty' do
      expect { MemoryRange.new(TEST_UPPER_BOUND, TEST_LOWER_BOUND) }.to raise_error(/Invalid range/)
    end

    it 'should fail if the lower bound is not a MemorySize' do
      expect { MemoryRange.new('', TEST_UPPER_BOUND) }.to raise_error(/Invalid combination of parameter types/)
    end

    it 'should fail if the upper bound is not a MemorySize' do
      expect { MemoryRange.new(TEST_LOWER_BOUND, '') }.to raise_error(/Invalid MemorySize parameter of type/)
    end

    it 'should accept valid lower and upper bounds' do
      range = MemoryRange.new(TEST_LOWER_BOUND, TEST_UPPER_BOUND)
      expect(range.floor).to eq(TEST_LOWER_BOUND)
      expect(range.ceiling).to eq(TEST_UPPER_BOUND)
      expect(range.bounded?).to be(true)
    end

    it 'should accept a lower bound and no upper bound' do
      range = MemoryRange.new(TEST_LOWER_BOUND)
      expect(range.floor).to eq(TEST_LOWER_BOUND)
      expect(range.ceiling).to be_nil
      expect(range.bounded?).to be(false)
    end

    it 'should correctly detect a degenerate range constructed from MemorySizes' do
      range = MemoryRange.new(TEST_LOWER_BOUND, TEST_LOWER_BOUND)
      expect(range.degenerate?).to eq(true)
    end

    it 'should correctly detect a non-degenerate range constructed from MemorySizes' do
      range = MemoryRange.new(TEST_LOWER_BOUND, TEST_UPPER_BOUND)
      expect(range.degenerate?).to eq(false)
    end

    it 'should product the correct string representation' do
      range = MemoryRange.new('3m..5m')
      expect(range.to_s).to eq('3M..5M')
    end

    it 'should support multiplication by a numeric' do
      range = MemoryRange.new('3m..5m')
      expect(range * 2).to eq(MemoryRange.new('6m..10m'))
    end

    it 'should compare bounded ranges correctly for equality' do
      expect(MemoryRange.new('3m..5m')).to eq(MemoryRange.new(TEST_LOWER_BOUND, TEST_UPPER_BOUND))
    end

    it 'should compare unbounded ranges correctly for equality' do
      expect(MemoryRange.new('3m..')).to eq(MemoryRange.new(TEST_LOWER_BOUND))
    end

  end

end
