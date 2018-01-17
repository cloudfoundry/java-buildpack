# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/util/cache/cache_factory'
require 'java_buildpack/util/cache/download_cache'

describe JavaBuildpack::Util::Cache::CacheFactory do
  include_context 'with application help'
  include_context 'with internet availability help'
  include_context 'with logging help'

  previous_arg_value = ARGV[1]

  before do
    ARGV[1] = nil
  end

  after do
    ARGV[1] = previous_arg_value
  end

  it 'returns an ApplicationCache if ARGV[1] is defined' do
    ARGV[1] = app_dir

    expect(described_class.create).to be_instance_of JavaBuildpack::Util::Cache::ApplicationCache
  end

  it 'returns a DownloadCache if ARGV[1] is not defined' do
    expect(described_class.create).to be_instance_of JavaBuildpack::Util::Cache::DownloadCache
  end

end
