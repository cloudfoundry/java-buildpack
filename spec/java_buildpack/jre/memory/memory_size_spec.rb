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

module JavaBuildpack::Jre

  describe MemorySize do

    let(:half_meg) { MemorySize.new('512K') }

    let(:one_meg) { MemorySize.new('1M') }

    it 'should accept a memory size in bytes, kilobytes, megabytes, or gigabytes' do
      expect(MemorySize.new('1024B')).to eq(MemorySize.new('1k'))
      expect(MemorySize.new('1024b')).to eq(MemorySize.new('1k'))
      expect(MemorySize.new('1M')).to eq(MemorySize.new('1024k'))
      expect(MemorySize.new('1m')).to eq(MemorySize.new('1024k'))
      expect(MemorySize.new('1G')).to eq(MemorySize.new('1048576k'))
      expect(MemorySize.new('1g')).to eq(MemorySize.new('1048576k'))
    end

    it 'should fail if nil is passed to  the constructor' do
      expect { MemorySize.new(nil) }.to raise_error /Invalid/
    end

    it 'should accept a zero memory size with no unit' do
      expect(MemorySize.new('0')).to eq(MemorySize.new('0k'))
    end

    it 'should fail if a non-zero memory size does not have a unit' do
      expect { MemorySize.new('1') }.to raise_error /Invalid/
    end

    it 'should fail if a memory size has an invalid unit' do
      expect { MemorySize.new('1A') }.to raise_error /Invalid/
    end

    it 'should fail if a memory size is not an number' do
      expect { MemorySize.new('xm') }.to raise_error /Invalid/
    end

    it 'should fail if a memory size is not an integer' do
      expect { MemorySize.new('1.1m') }.to raise_error /Invalid/
    end

    it 'should fail if a memory size has embedded whitespace' do
      expect { MemorySize.new('1 1m') }.to raise_error /Invalid/
    end

    it 'should accept a negative value' do
      expect(MemorySize.new('-1M')).to eq(MemorySize.new('-1024k'))
    end

    it 'should compare values correctly' do
      expect(one_meg).to be < MemorySize.new('1025K')
      expect(MemorySize.new('1025K')).to be > one_meg
    end

    it 'should compare a MemorySize to 0' do
      expect(one_meg).to be > 0
    end

    it 'should fail when a memory size is compared to a non-zero numeric' do
      expect { MemorySize.new('1B') < 2 }.to raise_error /Cannot compare/
    end

    it 'should multiply values correctly' do
      expect(one_meg * 2).to eq(MemorySize.new('2M'))
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
      expect(MemorySize.new('3B') / 2).to eq(MemorySize.new('2B'))
    end

    it 'should divide a memory size by another memory size correctly' do
      expect(one_meg / half_meg).to eq(2)
    end

    it 'should divide a memory size by another memory size using floating point' do
      expect(half_meg / one_meg).to eq(0.5)
    end

    it 'should fail when a memory size is divided by an incorrect type' do
      expect { MemorySize.new('1B') / '' }.to raise_error /Cannot divide/
    end

    it 'should provide a zero memory size' do
      expect(MemorySize::ZERO).to eq(JavaBuildpack::Jre::MemorySize.new('0B'))
    end

    it 'should correctly convert the memory size to a string' do
      expect(MemorySize::ZERO.to_s).to eq('0')
      expect(MemorySize.new('1K').to_s).to eq('1K')
      expect(MemorySize.new('1k').to_s).to eq('1K')
      expect(MemorySize.new('1M').to_s).to eq('1M')
      expect(MemorySize.new('1m').to_s).to eq('1M')
      expect(MemorySize.new('1G').to_s).to eq('1G')
      expect(MemorySize.new('1g').to_s).to eq('1G')
    end

  end

end
