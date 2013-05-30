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

describe 'detect script' do

  it 'should return non-zero if vendor is invalid' do
    Open3.popen3("bin/detect spec/fixtures/invalid_vendor") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to_not be_success
      expect(stderr.read).to eq("Invalid JRE vendor 'sun'\n")
    end
  end

  it 'should return non-zero if version is invalid' do
    Open3.popen3("bin/detect spec/fixtures/invalid_version") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to_not be_success
      expect(stderr.read).to match(/^No version resolvable for '5' in /)
    end
  end

  it 'should return zero if success' do
    Open3.popen3("bin/detect spec/fixtures/single_system_properties") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to be_success
    end
  end

end
