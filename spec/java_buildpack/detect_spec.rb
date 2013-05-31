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

describe JavaBuildpack::Detect do
  TEST_VENDOR = 'test-vendor'
  TEST_VERSION = 'test-version'

  it 'should return the id of the Java being used' do
    JavaBuildpack::JreProperties.any_instance.stub(:vendor).and_return(TEST_VENDOR)
    JavaBuildpack::JreProperties.any_instance.stub(:version).and_return(TEST_VERSION)

    components = JavaBuildpack::Detect.new('spec/fixtures/no_system_properties').run
    expect(components).to include("java-#{TEST_VENDOR}-#{TEST_VERSION}")
  end

end
