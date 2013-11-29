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
require 'java_buildpack/repository/version_resolver'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Repository::VersionResolver do

  let(:versions) { %w(1.6.0_26 1.6.0_27 1.6.1_14 1.7.0_19 1.7.0_21 1.8.0_M-7 1.8.0_05 2.0.0) }

  it 'resolves the default version if no candidate is supplied' do
    expect(described_class.resolve(nil, versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a wildcard major version' do
    expect(described_class.resolve(tokenized_version('+'), versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a wildcard minor version' do
    expect(described_class.resolve(tokenized_version('1.+'), versions)).to eq(tokenized_version('1.8.0_05'))
  end

  it 'resolves a wildcard micro version' do
    expect(described_class.resolve(tokenized_version('1.6.+'), versions)).to eq(tokenized_version('1.6.1_14'))
  end

  it 'resolves a wildcard qualifier' do
    expect(described_class.resolve(tokenized_version('1.6.0_+'), versions)).to eq(tokenized_version('1.6.0_27'))
    expect(described_class.resolve(tokenized_version('1.8.0_+'), versions)).to eq(tokenized_version('1.8.0_05'))
  end

  it 'resolves a non-wildcard version' do
    expect(described_class.resolve(tokenized_version('1.6.0_26'), versions)).to eq(tokenized_version('1.6.0_26'))
    expect(described_class.resolve(tokenized_version('2.0.0'), versions)).to eq(tokenized_version('2.0.0'))
  end

  it 'resolves a non-digit qualifier' do
    expect(described_class.resolve(tokenized_version('1.8.0_M-7'), versions)).to eq(tokenized_version('1.8.0_M-7'))
  end

  it 'should raise an exception if no version can be resolved' do
    expect { described_class.resolve(tokenized_version('2.1.0'), versions) }.to raise_error
  end

  it 'should raise an exception when a wildcard is specified in the [] collection' do
    expect { described_class.resolve(tokenized_version('1.6.0_25'), %w(+)) }.to raise_error /Invalid/
  end

  def tokenized_version(s)
    JavaBuildpack::Util::TokenizedVersion.new(s)
  end

end
