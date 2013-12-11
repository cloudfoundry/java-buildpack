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
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'

describe JavaBuildpack::Jre::MemoryBucket do
  include_context 'logging_helper'

  let(:test_name) { 'bucket-name' }
  let(:test_weighting) { 0.5 }
  let(:test_range) { JavaBuildpack::Jre::MemoryRange.new('10M..10M') }

  it 'should fail to construct if name is nil' do
    expect { described_class.new(nil, test_weighting, test_range) }.to raise_error /Invalid MemoryBucket name/
  end

  it 'should fail to construct if name is the empty string' do
    expect { described_class.new('', test_weighting, test_range) }.to raise_error /Invalid MemoryBucket name/
  end

  it 'should fail to construct if weighting is nil' do
    expect { described_class.new(test_name, nil, test_range) }.to raise_error /Invalid weighting/
  end

  it 'should fail to construct if weighting is not numeric' do
    expect { described_class.new(test_name, 'x', test_range) }.to raise_error /Invalid weighting/
  end

  it 'should fail to construct if weighting is negative' do
    expect { described_class.new(test_name, -0.1, test_range) }.to raise_error /Invalid weighting/
  end

  it 'should initialise size to nil' do
    memory_bucket = described_class.new(test_name, test_weighting, test_range)
    expect(memory_bucket.size).to eq(nil)
  end

  it 'should fail to construct if range is invalid' do
    expect { described_class.new(test_name, test_weighting, 'x') }.to raise_error /Invalid\ 'range'\ parameter/
  end

end
