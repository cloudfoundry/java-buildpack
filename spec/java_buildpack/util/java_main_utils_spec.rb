# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/buildpack'
require 'java_buildpack/util/java_main_utils'

describe JavaBuildpack::Util::JavaMainUtils do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:test_class_name) { 'test-java-main-class' }

  it 'uses a main class configuration in a configuration file' do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('java_main')
      .and_return('java_main_class' => test_class_name)

    expect(described_class.main_class(application)).to eq(test_class_name)
  end

  it 'uses a main class configuration in a configuration parameter' do
    expect(described_class.main_class(application, 'java_main_class' => test_class_name)).to eq(test_class_name)
  end

  it 'uses a main class in the manifest of the application',
     app_fixture: 'container_main' do

    expect(described_class.main_class(application)).to eq('test-main-class')
  end

end
