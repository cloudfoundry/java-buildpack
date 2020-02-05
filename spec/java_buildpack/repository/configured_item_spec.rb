# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/repository/repository_index'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Repository::ConfiguredItem do

  let(:repository_index) { instance_double('RepositoryIndex', find_item: [resolved_version, resolved_uri]) }

  let(:resolved_uri) { 'resolved-uri' }

  let(:resolved_version) { 'resolved-version' }

  before do
    allow(JavaBuildpack::Repository::RepositoryIndex).to receive(:new).and_return(repository_index)
  end

  it 'raises an error if no repository root is specified' do
    expect { described_class.find_item('Test', {}) }.to raise_error(/A repository root must be specified/)
  end

  it 'resolves a system.properties version if specified' do
    details = described_class.find_item('Test',
                                        'repository_root' => 'test-repository-root',
                                        'java.runtime.version' => 'test-java-runtime-version',
                                        'version' => '1.7.0')

    expect(details[0]).to eq(resolved_version)
    expect(details[1]).to eq(resolved_uri)
  end

  it 'resolves a configuration version if specified' do
    details = described_class.find_item('Test',
                                        'repository_root' => 'test-repository-root',
                                        'version' => '1.7.0')

    expect(details[0]).to eq(resolved_version)
    expect(details[1]).to eq(resolved_uri)
  end

  it 'drives the version validator block if supplied' do
    described_class.find_item('Test',
                              'repository_root' => 'test-repository-root',
                              'version' => '1.7.0') do |version|
      expect(version).to eq(JavaBuildpack::Util::TokenizedVersion.new('1.7.0'))
    end
  end

  it 'resolves nil if no version is specified' do
    details = described_class.find_item('Test',
                                        'repository_root' => 'test-repository-root')

    expect(details[0]).to eq(resolved_version)
    expect(details[1]).to eq(resolved_uri)
  end

end
