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
require 'open3'

describe 'release script', :integration do
  include_context 'application_helper'

  it 'should return zero if success',
     app_fixture: 'integration_valid' do

    Open3.popen3("bin/release #{app_dir}") do |stdin, stdout, stderr, wait_thr|
      expect(wait_thr.value).to be_success
    end

  end

  it 'should fail to release when no containers detect' do
    error = Open3.capture3("bin/release #{app_dir}")[1]
    expect(error).to match /No container can run the application/
  end

end
