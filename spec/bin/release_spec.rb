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
require 'open3'

describe 'release' do

  it 'should return zero if the release is successful' do
    # TODO Implement test as things are filled out
  end

  it 'should return non-zero if an error occurs' do
    # TODO Implement test as things are filled out
  end

  it 'should print the error message if an error occurs' do
    # TODO Implement test as things are filled out
  end

  private

  COMPILE = File.expand_path('../../../bin/release', __FILE__)
  FIXTURES_DIR = File.expand_path('../../fixtures', __FILE__)

end
