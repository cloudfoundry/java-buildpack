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
require 'java_buildpack/jre/memory/memory_bucket'

module JavaBuildpack::Jre

  describe MemoryBucket do

    TEST_NAME = 'bucket-name'
    TEST_WEIGHTING = 0.5
    TEST_SIZE = MemorySize.new('10M')
    TEST_TOTAL_MEMORY = MemorySize.new('1G')
    TEST_TOTAL_EXCESS = MemorySize.new('200B')

    it 'should fail to construct if name is nil' do
      expect { MemoryBucket.new(nil, TEST_WEIGHTING, TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid MemoryBucket name/)
    end

    it 'should fail to construct if name is the empty string' do
      expect { MemoryBucket.new('', TEST_WEIGHTING, TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid MemoryBucket name/)
    end

    it 'should fail to construct if weighting is nil' do
      expect { MemoryBucket.new(TEST_NAME, nil, TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should fail to construct if weighting is not numeric' do
      expect { MemoryBucket.new(TEST_NAME, 'x', TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should fail to construct if weighting is negative' do
      expect { MemoryBucket.new(TEST_NAME, -0.1, TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should fail to construct if weighting is greater than 1' do
      expect { MemoryBucket.new(TEST_NAME, 1.1, TEST_SIZE, true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should record a non-nil size' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.size).to eq(TEST_SIZE)
    end

    it 'should calculate the correct default size' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.default_size).to eq(TEST_TOTAL_MEMORY * TEST_WEIGHTING)
    end

    it 'should apply the default if a nil size is specified' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, nil, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.size).to eq(TEST_TOTAL_MEMORY * TEST_WEIGHTING)
    end

    it 'should fail to construct if size is non-numeric' do
      expect { MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, 'x', true, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid\ 'size'\ parameter/)
    end

    it 'should fail to construct if adjustable is not true or false' do
      expect { MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, nil, TEST_TOTAL_MEMORY) }
      .to raise_error(/Invalid\ 'adjustable'\ parameter/)
    end

    it 'should record the size if total_memory is nil' do
      expect(MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, nil).size).to eq(TEST_SIZE)
    end

    it 'should return a zero excess if total_memory is nil' do
      expect(MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, nil).excess) .to eq(MemorySize::ZERO)
    end

    it 'should return a zero adjustable weighting if total_memory is nil' do
      expect(MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, nil).adjustable_weighting).to eq(0)
    end

    it 'should return a nil default size if total_memory is nil' do
      expect(MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, nil).default_size).to be_nil
    end

    it 'should cope with adjust being called if total_memory is nil' do
      MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, nil).adjust(MemorySize::ZERO, 0)
    end

    it 'should fail to construct if total_memory is non-numeric' do
      expect { MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, 'x') }
      .to raise_error(/Invalid\ 'total_memory'\ parameter/)
    end

    it 'should calculate the excess memory correctly' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.excess).to eq(TEST_SIZE - TEST_TOTAL_MEMORY * TEST_WEIGHTING)
    end

    it 'should return a zero excess if the size has not been set' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, nil, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.excess).to eq(MemorySize::ZERO)
    end

    it 'should return an adjustable weighting of the weighting if it is adjustable' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, nil, true, TEST_TOTAL_MEMORY)
      expect(memory_bucket.adjustable_weighting).to eq(TEST_WEIGHTING)
    end

    it 'should return an adjustable weighting of zero if it is not adjustable' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_SIZE, false, TEST_TOTAL_MEMORY)
      expect(memory_bucket.adjustable_weighting).to eq(0)
    end

    it 'should adjust the size correctly if it is adjustable' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, nil, true, TEST_TOTAL_MEMORY)
      memory_bucket.adjust(TEST_TOTAL_EXCESS, 2 * TEST_WEIGHTING)
      expect(memory_bucket.size).to eq(TEST_TOTAL_MEMORY * TEST_WEIGHTING - TEST_TOTAL_EXCESS / 2)
    end

    it 'should adjust the size correctly if it is adjustable and the total adjustable weighting is 0' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, nil, true, TEST_TOTAL_MEMORY)
      memory_bucket.adjust(TEST_TOTAL_EXCESS, 0)
      expect(memory_bucket.size).to eq(MemorySize::ZERO)
    end

  end

end
