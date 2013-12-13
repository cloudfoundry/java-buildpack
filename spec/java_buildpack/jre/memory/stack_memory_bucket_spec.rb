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
require 'java_buildpack/jre/memory/stack_memory_bucket'
require 'java_buildpack/jre/memory/memory_bucket'
require 'java_buildpack/jre/memory/memory_range'
require 'java_buildpack/jre/memory/memory_size'

describe JavaBuildpack::Jre::StackMemoryBucket do
  include_context 'logging_helper'

  let(:test_stack_bucket_weighting) { 0.05 }
  let(:test_stack_size) { JavaBuildpack::Jre::MemorySize.new('2M') }
  let(:test_stack_size_range) { JavaBuildpack::Jre::MemoryRange.new(test_stack_size, test_stack_size) }

  it 'should call the superclass constructor correctly' do
    # since we can't easily stub the superclass, test the superclass behaves as expected
    stack_memory_bucket = described_class.new(test_stack_bucket_weighting, test_stack_size_range)
    expect(stack_memory_bucket.range).to eq(test_stack_size_range)
  end

end
