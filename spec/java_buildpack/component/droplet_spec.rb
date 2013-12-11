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
require 'application_helper'
require 'droplet_helper'
require 'fileutils'
require 'java_buildpack/component/droplet'
require 'pathname'

describe JavaBuildpack::Component::Droplet do
  include_context 'application_helper'
  include_context 'droplet_helper'

  it 'should return additional_libraries' do
    expect(droplet.additional_libraries).to equal(additional_libraries)
  end

  it 'should return component_id' do
    expect(droplet.component_id).to eq(component_id)
  end

  it 'should return java_home' do
    expect(droplet.java_home).to equal(java_home)
  end

  it 'should return java_opts' do
    expect(droplet.java_opts).to equal(java_opts)
  end

  it 'should return an existent child if in application' do
    FileUtils.touch(app_dir + 'test-file')

    expect(droplet.root + 'test-file').to exist
  end

  it 'should return an existent child if in sandbox' do
    FileUtils.mkdir_p(app_dir + '.java-buildpack/droplet')
    FileUtils.touch(app_dir + '.java-buildpack/droplet/test-file')

    expect(droplet.sandbox + 'test-file').to exist
  end

  it 'should return a non-existent child if in buildpack but not sandbox' do
    FileUtils.mkdir_p(app_dir + '.java-buildpack')
    FileUtils.touch(app_dir + '.java-buildpack/test-file')

    expect(droplet.root + '.java-buildpack/test-file').not_to exist
  end

  it 'should expose a sandbox for the component based on its component_id' do
    expect(droplet.sandbox).to eq(app_dir + '.java-buildpack/droplet')
  end

  context do
    let(:fixtures_directory) { Pathname.new('spec/fixtures') }

    it 'should copy resources if resources directory exists' do
      stub_const(described_class.to_s + '::RESOURCES_DIRECTORY', fixtures_directory)
      allow(fixtures_directory).to receive(:+).with('droplet').and_return(fixtures_directory + 'droplet-resources')

      droplet.copy_resources

      expect(droplet.sandbox + 'droplet-resource').to exist
    end
  end

  it 'should not copy resources if resource directory does not exist' do
    droplet.copy_resources
  end

end
