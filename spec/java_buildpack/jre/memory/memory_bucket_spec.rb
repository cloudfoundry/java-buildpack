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
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack::Jre

  describe MemoryBucket do

    TEST_NAME = 'bucket-name'
    TEST_WEIGHTING = 0.5
    TEST_RANGE = MemoryRange.new('10M..10M')
    TEST_TOTAL_MEMORY = MemorySize.new('1G')
    TEST_TOTAL_EXCESS = MemorySize.new('200B')

    it 'should fail to construct if name is nil' do
      expect { MemoryBucket.new(nil, TEST_WEIGHTING, TEST_RANGE) }
      .to raise_error(/Invalid MemoryBucket name/)
    end

    it 'should fail to construct if name is the empty string' do
      expect { MemoryBucket.new('', TEST_WEIGHTING, TEST_RANGE) }
      .to raise_error(/Invalid MemoryBucket name/)
    end

    it 'should fail to construct if weighting is nil' do
      expect { MemoryBucket.new(TEST_NAME, nil, TEST_RANGE) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should fail to construct if weighting is not numeric' do
      expect { MemoryBucket.new(TEST_NAME, 'x', TEST_RANGE) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should fail to construct if weighting is negative' do
      expect { MemoryBucket.new(TEST_NAME, -0.1, TEST_RANGE) }
      .to raise_error(/Invalid weighting/)
    end

    it 'should initialise size to nil' do
      memory_bucket = MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, TEST_RANGE)
      expect(memory_bucket.size).to eq(nil)
    end

    it 'should fail to construct if range is invalid' do
      expect { MemoryBucket.new(TEST_NAME, TEST_WEIGHTING, 'x') }
      .to raise_error(/Invalid\ 'range'\ parameter/)
    end

  end

end
