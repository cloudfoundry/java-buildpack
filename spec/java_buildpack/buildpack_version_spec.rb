# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'application_helper'
require 'logging_helper'
require 'java_buildpack/buildpack_version'
require 'pathname'

describe JavaBuildpack::BuildpackVersion do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:buildpack_version) { described_class.new }

  before do |example|
    configuration = example.metadata[:configuration] || {}
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('version', true, true)
                                                                    .and_return(configuration)
  end

  it 'creates offline version string from config/version.yml',
     log_level:     'DEBUG',
     configuration: { 'hash'   => 'test-hash', 'offline' => true,
                      'remote' => 'test-remote', 'version' => 'test-version' } do

    expect(buildpack_version.to_s).to match(/test-version (offline) | test-remote#test-hash/)
    expect(buildpack_version.to_s(false)).to match(/test-version-offline-test-remote#test-hash/)
    expect(stderr.string).to match(/test-version (offline) | test-remote#test-hash/)
  end

  it 'creates online version string from config/version.yml',
     log_level:     'DEBUG',
     configuration: { 'hash'   => 'test-hash', 'offline' => false,
                      'remote' => 'test-remote', 'version' => 'test-version' } do

    expect(buildpack_version.to_s).to match(/test-version | test-remote#test-hash/)
    expect(buildpack_version.to_s(false)).to match(/test-version-test-remote#test-hash/)
    expect(stderr.string).to match(/test-version | test-remote#test-hash/)
  end

  it 'creates version string from git repository if no config/version.yml exists',
     log_level: 'DEBUG' do

    git_dir = Pathname.new('.git').expand_path

    allow_any_instance_of(described_class).to receive(:system)
      .with('which git > /dev/null')
      .and_return(true)
    allow_any_instance_of(described_class).to receive(:`)
      .with("git --git-dir=#{git_dir} rev-parse --short HEAD")
      .and_return('test-hash')
    allow_any_instance_of(described_class).to receive(:`)
      .with("git --git-dir=#{git_dir} config --get remote.origin.url")
      .and_return('test-remote')

    expect(buildpack_version.to_s).to match(/test-remote#test-hash/)
    expect(buildpack_version.to_s(false)).to match(/test-remote#test-hash/)
    expect(stderr.string).to match(/test-remote#test-hash/)
  end

  it 'creates unknown version string if no config/version.yml exists and it is not in a git repository',
     log_level: 'DEBUG' do

    allow_any_instance_of(described_class).to receive(:system).with('which git > /dev/null').and_return(false)

    expect(buildpack_version.to_s).to match(/unknown/)
    expect(buildpack_version.to_s(false)).to match(/unknown/)
    expect(stderr.string).to match(/unknown/)
  end

  it 'creates a has from the values',
     configuration: { 'hash'   => 'test-hash', 'offline' => true,
                      'remote' => 'test-remote', 'version' => 'test-version' } do |example|

    allow_any_instance_of(described_class).to receive(:system).with('which git > /dev/null').and_return(false)

    expect(buildpack_version.to_hash).to eq(example.metadata[:configuration])
  end

  it 'excludes non-populated values from the hash' do
    allow_any_instance_of(described_class).to receive(:system).with('which git > /dev/null').and_return(false)

    expect(buildpack_version.to_hash).to eq({})
  end

  it 'excludes remote string when remote and hash values from config/version.yml are empty',
     configuration: { 'hash' => '', 'remote' => '', 'version' => 'test-version' } do
    expect(buildpack_version.to_s).to eq('test-version')
  end

  it 'includes remote string when remote and hash values from config/version.yml are missing',
     configuration: { 'version' => 'test-version' } do

    git_dir = Pathname.new('.git').expand_path
    allow_any_instance_of(described_class).to receive(:system)
      .with('which git > /dev/null')
      .and_return(true)
    allow_any_instance_of(described_class).to receive(:`)
      .with("git --git-dir=#{git_dir} rev-parse --short HEAD")
      .and_return('test-hash')
    allow_any_instance_of(described_class).to receive(:`)
      .with("git --git-dir=#{git_dir} config --get remote.origin.url")
      .and_return('test-remote')

    expect(buildpack_version.to_s).to eq('test-version | test-remote#test-hash')
  end

  context do

    let(:environment) { { 'OFFLINE' => 'true' } }

    it 'picks up offline from the environment' do
      allow_any_instance_of(described_class).to receive(:system).with('which git > /dev/null').and_return(false)

      expect(buildpack_version.offline).to be
    end

  end

  context do

    let(:environment) { { 'VERSION' => 'test-version' } }

    it 'picks up version from the environment' do
      allow_any_instance_of(described_class).to receive(:system).with('which git > /dev/null').and_return(false)

      expect(buildpack_version.version).to match(/test-version/)
    end

  end

end
