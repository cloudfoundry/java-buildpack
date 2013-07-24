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
require 'java_buildpack/jre/memory/memory_limit'
require 'java_buildpack/jre/memory/memory_size'

module JavaBuildpack::Jre

  describe MemoryLimit do

    it 'should accept a memory limit in megabytes or gigabytes' do
      with_memory_limit('1G') do
        expect(MemoryLimit.memory_limit).to eq(MemorySize.new('1048576K'))
      end
      with_memory_limit('1g') do
        expect(MemoryLimit.memory_limit).to eq(MemorySize.new('1048576K'))
      end
      with_memory_limit('1M') do
        expect(MemoryLimit.memory_limit).to eq(MemorySize.new('1024K'))
      end
      with_memory_limit('1m') do
        expect(MemoryLimit.memory_limit).to eq(MemorySize.new('1024K'))
      end
    end

    it 'should return nil if a memory limit is not specified' do
      with_memory_limit(nil) do
        expect(MemoryLimit.memory_limit).to be_nil
      end
    end

    it 'should fail if a memory limit does not have a unit' do
      with_memory_limit('1') do
        expect { MemoryLimit.memory_limit }.to raise_error(/Invalid/)
      end
    end

    it 'should fail if a memory limit is not an number' do
      with_memory_limit('xm') do
        expect { MemoryLimit.memory_limit }.to raise_error(/Invalid/)
      end
    end

    it 'should fail if a memory limit is not an integer' do
      with_memory_limit('1.1m') do
        expect { MemoryLimit.memory_limit }.to raise_error(/Invalid/)
      end
    end

    it 'should fail if a memory limit is negative' do
      with_memory_limit('-1m') do
        expect { MemoryLimit.memory_limit }.to raise_error(/Invalid/)
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

end
