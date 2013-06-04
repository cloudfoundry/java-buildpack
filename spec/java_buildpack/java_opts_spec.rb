# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

describe JavaBuildpack::JavaOpts do

  HEAP_SIZE_MAXIMUM = '1024m'

  INVALID_HEAP_SIZE_MAXIMUM = '1024m -Xint'

  PERM_GEN_SIZE_MAXIMUM = '128m'

  INVALID_PERM_GEN_SIZE_MAXIMUM = '128m -Xint'

  STACK_SIZE = '128k'

  INVALID_STACK_SIZE = '128k -Xint'

  let(:value_resolver) { double('ValueResolver') }

  it 'returns the resolved stack size' do
    initialize_value_resolution :stack_size => STACK_SIZE

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.stack_size).to eq("-Xss#{STACK_SIZE}")
  end

  it 'returns nil when the stack size is not specified' do
    initialize_value_resolution

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.stack_size).to be_nil
  end

  it 'raises an error when the stack size has embedded whitespace' do
    initialize_value_resolution :stack_size => INVALID_STACK_SIZE

    expect { JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties') }.to raise_error
  end

  it 'returns the resolved heap size maximum' do
    initialize_value_resolution :heap_size_maximum => HEAP_SIZE_MAXIMUM

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.heap_size_maximum).to eq("-Xmx#{HEAP_SIZE_MAXIMUM}")
  end

  it 'returns nil when the heap size maximum is not specified' do
    initialize_value_resolution

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.heap_size_maximum).to be_nil
  end

  it 'raises an error when the heap size maximum has embedded whitespace' do
    initialize_value_resolution :heap_size_maximum => INVALID_HEAP_SIZE_MAXIMUM

    expect { JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties') }.to raise_error
  end

  it 'returns the resolved PermGen size maximum' do
    initialize_value_resolution :perm_gen_size_maximum => PERM_GEN_SIZE_MAXIMUM

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.perm_gen_size_maximum).to eq("-XX:MaxPermSize=#{PERM_GEN_SIZE_MAXIMUM}")
  end

  it 'returns nil when the heap size maximum is not specified' do
    initialize_value_resolution

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.perm_gen_size_maximum).to be_nil
  end

  it 'raises an error when the heap size maximum has embedded whitespace' do
    initialize_value_resolution :perm_gen_size_maximum => INVALID_PERM_GEN_SIZE_MAXIMUM

    expect { JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties') }.to raise_error
  end

  it 'returns a space delimited string of all Java options' do
    initialize_value_resolution(
      :heap_size_maximum => HEAP_SIZE_MAXIMUM,
      :perm_gen_size_maximum => PERM_GEN_SIZE_MAXIMUM,
      :stack_size => STACK_SIZE
    )

    java_opts = JavaBuildpack::JavaOpts.new('spec/fixtures/no_system_properties')

    expect(java_opts.to_s).to eq("-XX:MaxPermSize=#{PERM_GEN_SIZE_MAXIMUM} -Xmx#{HEAP_SIZE_MAXIMUM} -Xss#{STACK_SIZE}")
  end

  private

  def initialize_value_resolution(values = {})
    JavaBuildpack::ValueResolver.stub(:new).with('spec/fixtures/no_system_properties').and_return(value_resolver)

    value_resolver.stub(:resolve).with('JAVA_RUNTIME_HEAP_SIZE_MAXIMUM', 'java.runtime.heap.size.maximum')
      .and_return(values[:heap_size_maximum])
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_PERM_GEN_SIZE_MAXIMUM', 'java.runtime.perm.gen.size.maximum')
      .and_return(values[:perm_gen_size_maximum])
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_STACK_SIZE', 'java.runtime.stack.size')
      .and_return(values[:stack_size])
  end

end
