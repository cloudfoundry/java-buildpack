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
require 'internet_availability_helper'
require 'logging_helper'
require 'java_buildpack/util/cache/application_cache'

describe JavaBuildpack::Util::Cache::ApplicationCache do
  include_context 'application_helper'
  include_context 'internet_availability_helper'
  include_context 'logging_helper'

  previous_arg_value = ARGV[1]

  before do
    ARGV[1] = nil

    stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    stub_request(:head, 'http://foo-uri/')
      .with(headers: { 'Accept'     => '*/*', 'If-Modified-Since' => 'foo-last-modified', 'If-None-Match' => 'foo-etag',
                       'User-Agent' => 'Ruby' })
      .to_return(status: 304, body: '', headers: {})
  end

  after do
    ARGV[1] = previous_arg_value
  end

  it 'raises an error if ARGV[1] is not defined' do
    expect { described_class.new }.to raise_error
  end

  it 'uses ARGV[1] directory' do
    ARGV[1] = app_dir

    described_class.new.get('http://foo-uri/') {}

    expect(Pathname.glob(app_dir + '*.cached').size).to eq(1)
  end

end
