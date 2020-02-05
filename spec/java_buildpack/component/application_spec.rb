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
require 'application_helper'
require 'fileutils'
require 'java_buildpack/component/application'

describe JavaBuildpack::Component::Application do
  include_context 'with application help'

  it 'returns a parsed version of VCAP_APPLICATION as details' do
    expect(application.details).to eq(vcap_application)
  end

  it 'removes VCAP_APPLICATION and VCAP_SERVICES from environment' do
    expect(application.environment).to include('test-key')
    expect(application.environment).not_to include('VCAP_APPLICATION')
    expect(application.environment).not_to include('VCAP_SERVICES')
  end

  it 'returns a child path if it does not exist' do
    expect(application.root + 'test-file').not_to be_nil
  end

  it 'does not return a child path that does not exist if it exists but is not in the initial contents' do
    FileUtils.touch(app_dir + 'test-file')

    expect(application.root + 'test-file').not_to exist
  end

  it 'returns a child path if it exists and is in the initial contents',
     app_fixture: 'application' do

    expect(application.root + 'test-file').not_to be_nil
  end

  it 'only lists children that exist initially',
     app_fixture: 'application' do

    FileUtils.mkdir_p(app_dir + '.ignore-directory')
    FileUtils.mkdir_p(app_dir + 'ignore-directory')
    FileUtils.touch(app_dir + '.ignore-file')
    FileUtils.touch(app_dir + 'ignore-file')

    children = application.root.children
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

  it 'returns a parsed version of VCAP_SERVICES as services' do
    expect(application.services.find_service(/test-service/)).to be_truthy
  end

end
