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
    Open3.popen3("bin/release spec/fixtures/java") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to be_success
    end
  end

  it 'should print the execution command payload' do
    Open3.popen3("bin/release spec/fixtures/java") do |stdin, stdout, stderr, wait_thr|
      expect(stdout.read).to match("---\n:addons: \\[\\]\n:config_vars: {}\n:default_process_types:\n  :web: ''\n")
    end
  end

end
