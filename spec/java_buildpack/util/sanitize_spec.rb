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
require 'java_buildpack/util/sanitizer'

describe 'sanitize_uri' do # rubocop:disable RSpec/DescribeClass
  include_context 'with application help'

  it 'sanitizes uri with credentials in' do
    expect('https://myuser:mypass@myhost/path/to/file'.sanitize_uri).to eq('https://myhost/path/to/file')
  end

  it 'does not sanatize uri with no credentials in' do
    expect('https://myhost/path/to/file'.sanitize_uri).to eq('https://myhost/path/to/file')
  end

end
