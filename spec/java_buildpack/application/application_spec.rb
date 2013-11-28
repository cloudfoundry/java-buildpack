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
require 'fileutils'
require 'java_buildpack/application/application'

describe JavaBuildpack::Application::Application do
  include_context 'application_helper'

  it 'should return a child path if it does not exist' do
    expect(application.child('test-file')).not_to be_nil
  end

  it 'should not return a child path if it exists but is not in the initial contents' do
    FileUtils.touch app_dir + 'test-file'

    expect(application.child('test-file')).to be_nil
  end

  it 'should return a child path if it exists and is in the initial contents',
     app_fixture: 'application' do

    expect(application.child('test-file')).not_to be_nil
  end

  it 'should only list children that exist initially',
     app_fixture: 'application' do

    FileUtils.mkdir_p app_dir + '.ignore-directory'
    FileUtils.mkdir_p app_dir + 'ignore-directory'
    FileUtils.touch app_dir + '.ignore-file'
    FileUtils.touch app_dir + 'ignore-file'

    children = application.children
    expect(children.size).to eq(4)
    expect(children).to include(app_dir + '.test-directory')
    expect(children).to include(app_dir + 'test-directory')
    expect(children).to include(app_dir + '.test-file')
    expect(children).to include(app_dir + 'test-file')
    expect(children).not_to include(app_dir + '.ignore-directory')
    expect(children).not_to include(app_dir + 'ignore-directory')
    expect(children).not_to include(app_dir + '.ignore-file')
    expect(children).not_to include(app_dir + 'ignore-file')
  end

  it 'should return a component directory' do
    expect(application.component_directory('Test-Component')).to eq(app_dir + '.test-component')
  end

  it 'should return the path relative to the application root' do
    expect(application.relative_path_to(app_dir + 'test-directory/test-file'))
    .to eq(Pathname.new('test-directory/test-file'))
  end
end
