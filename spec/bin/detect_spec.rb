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
require 'integration_helper'

describe 'detect script', :integration do # rubocop:disable RSpec/DescribeClass
  include_context 'with integration help'

  it 'returns zero if success',
     app_fixture: 'integration_valid' do

    run("bin/detect #{app_dir}") do |status|
      expect(status).to be_success
      expect(stdout.string.rstrip.length).to be <= 255
    end
  end

  it 'fails to detect when no containers detect' do
    run("bin/detect #{app_dir}") do |status|
      expect(status).not_to be_success
      expect(stdout.string).to be_empty
    end
  end

  it 'truncates long detect strings',
     app_fixture: 'integration_valid',
     buildpack_fixture: 'integration_long_detect_tag' do

    run("bin/detect #{app_dir}") do |status|
      expect(status).to be_success
      expect(stdout.string.rstrip.length).to eq 255
      expect(stdout.string.rstrip).to end_with '...'
    end
  end

end
