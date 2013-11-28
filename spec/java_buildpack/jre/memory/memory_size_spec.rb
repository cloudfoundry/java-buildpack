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
require 'java_buildpack/jre/memory/memory_size'

describe JavaBuildpack::Jre::MemorySize do

  let(:half_meg) { described_class.new('512K') }

  let(:one_meg) { described_class.new('1M') }

  it 'should accept a memory size in bytes, kilobytes, megabytes, or gigabytes' do
    expect(described_class.new('1024B')).to eq(described_class.new('1k'))
    expect(described_class.new('1024b')).to eq(described_class.new('1k'))
    expect(described_class.new('1M')).to eq(described_class.new('1024k'))
    expect(described_class.new('1m')).to eq(described_class.new('1024k'))
    expect(described_class.new('1G')).to eq(described_class.new('1048576k'))
    expect(described_class.new('1g')).to eq(described_class.new('1048576k'))
  end

  it 'should fail if nil is passed to  the constructor' do
    expect { described_class.new(nil) }.to raise_error /Invalid/
  end

  it 'should accept a zero memory size with no unit' do
    expect(described_class.new('0')).to eq(described_class.new('0k'))
  end

  it 'should fail if a non-zero memory size does not have a unit' do
    expect { described_class.new('1') }.to raise_error /Invalid/
  end

  it 'should fail if a memory size has an invalid unit' do
    expect { described_class.new('1A') }.to raise_error /Invalid/
  end

  it 'should fail if a memory size is not an number' do
    expect { described_class.new('xm') }.to raise_error /Invalid/
  end

  it 'should fail if a memory size is not an integer' do
    expect { described_class.new('1.1m') }.to raise_error /Invalid/
  end

  it 'should fail if a memory size has embedded whitespace' do
    expect { described_class.new('1 1m') }.to raise_error /Invalid/
  end

  it 'should accept a negative value' do
    expect(described_class.new('-1M')).to eq(described_class.new('-1024k'))
  end

  it 'should compare values correctly' do
    expect(one_meg).to be < described_class.new('1025K')
    expect(described_class.new('1025K')).to be > one_meg
  end

  it 'should compare a described_class to 0' do
    expect(one_meg).to be > 0
  end

  it 'should fail when a memory size is compared to a non-zero numeric' do
    expect { described_class.new('1B') < 2 }.to raise_error /Cannot compare/
  end

  it 'should multiply values correctly' do
    expect(one_meg * 2).to eq(described_class.new('2M'))
  end

  it 'should fail when a memory size is multiplied by a memory size' do
    expect { one_meg * one_meg }.to raise_error /Cannot multiply/
  end

  it 'should subtract memory values correctly' do
    expect(one_meg - half_meg).to eq(half_meg)
  end

  it 'should fail when a numeric is subtracted from a memory size' do
    expect { one_meg - 1 }.to raise_error /Invalid parameter: instance of Fixnum is not a MemorySize/
  end

  it 'should add memory values correctly' do
    expect(half_meg + half_meg).to eq(one_meg)
  end

  it 'should fail when a numeric is added to a memory size' do
    expect { one_meg + 1 }.to raise_error /Invalid parameter: instance of Fixnum is not a MemorySize/
  end

  it 'should divide a memory size by a numeric correctly' do
    expect(one_meg / 2).to eq(half_meg)
  end

  it 'should divide a memory size by a numeric using floating point' do
    expect(described_class.new('3B') / 2).to eq(described_class.new('2B'))
  end

  it 'should divide a memory size by another memory size correctly' do
    expect(one_meg / half_meg).to eq(2)
  end

  it 'should divide a memory size by another memory size using floating point' do
    expect(half_meg / one_meg).to eq(0.5)
  end

  it 'should fail when a memory size is divided by an incorrect type' do
    expect { described_class.new('1B') / '' }.to raise_error /Cannot divide/
  end

  it 'should provide a zero memory size' do
    expect(described_class::ZERO).to eq(described_class.new('0B'))
  end

  it 'should correctly convert the memory size to a string' do
    expect(described_class::ZERO.to_s).to eq('0')
    expect(described_class.new('1K').to_s).to eq('1K')
    expect(described_class.new('1k').to_s).to eq('1K')
    expect(described_class.new('1M').to_s).to eq('1M')
    expect(described_class.new('1m').to_s).to eq('1M')
    expect(described_class.new('1G').to_s).to eq('1G')
    expect(described_class.new('1g').to_s).to eq('1G')
  end

end
