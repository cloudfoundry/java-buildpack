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
require 'memory_limit_helper'
require 'java_buildpack/jre/memory/memory_limit'
require 'java_buildpack/jre/memory/memory_size'

describe JavaBuildpack::Jre::MemoryLimit do
  include_context 'memory_limit_helper'

  it 'should accept memory with an uppercase G',
     memory_limit: '1G' do

    expect(described_class.memory_limit).to eq(JavaBuildpack::Jre::MemorySize.new('1048576K'))
  end

  it 'should accept memory with an lowercase G',
     memory_limit: '1g' do

    expect(described_class.memory_limit).to eq(JavaBuildpack::Jre::MemorySize.new('1048576K'))
  end

  it 'should accept memory with an uppercase M',
     memory_limit: '1M' do

    expect(described_class.memory_limit).to eq(JavaBuildpack::Jre::MemorySize.new('1024K'))
  end

  it 'should accept memory with an lowercase M',
     memory_limit: '1m' do

    expect(described_class.memory_limit).to eq(JavaBuildpack::Jre::MemorySize.new('1024K'))
  end

  it 'should return nil if a memory limit is not specified',
     memory_limit: nil do

    expect(described_class.memory_limit).to be_nil
  end

  it 'should fail if a memory limit does not have a unit',
     memory_limit: '-1' do

    expect { described_class.memory_limit }.to raise_error /Invalid/
  end

  it 'should fail if a memory limit is not an number',
     memory_limit: 'xm' do

    expect { described_class.memory_limit }.to raise_error /Invalid/
  end

  it 'should fail if a memory limit is not an integer',
     memory_limit: '-1.1m' do

    expect { described_class.memory_limit }.to raise_error /Invalid/
  end

  it 'should fail if a memory limit is negative',
     memory_limit: '-1m' do

    expect { described_class.memory_limit }.to raise_error /Invalid/
  end

end
