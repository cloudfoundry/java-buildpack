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

describe 'detect' do

  it 'should return non-zero if the application is not Java' do
    Open3.popen3("bin/detect spec/fixtures/non-java") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to_not be_success
    end
  end

  it 'should return zero if the application is Java' do
    Open3.popen3("bin/detect spec/fixtures/java") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to be_success
    end
  end

  it 'should print the names of participating components if the application is Java' do
    Open3.popen3("bin/detect spec/fixtures/java") do |stdin, stdout, stderr, wait_thr|
      expect(stdout.read).to match(/java-openjdk-8/)
    end
  end

end
