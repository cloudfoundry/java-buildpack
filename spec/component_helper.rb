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
require 'console_helper'
require 'droplet_helper'
require 'internet_availability_helper'
require 'logging_helper'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/cache/application_cache'
require 'java_buildpack/util/space_case'
require 'java_buildpack/util/tokenized_version'
require 'pathname'

shared_context 'component_helper' do
  include_context 'application_helper'
  include_context 'console_helper'
  include_context 'droplet_helper'
  include_context 'internet_availability_helper'
  include_context 'logging_helper'

  let(:application_cache) { instance_double('ApplicationCache') }

  let(:component) { described_class.new context }
  let(:configuration) { {} }

  let(:context) do
    { application:    application,
      component_name: described_class.to_s.split('::').last.space_case,
      configuration:  configuration,
      droplet:        droplet }
  end

  let(:uri) { 'test-uri' }
  let(:version) { '0.0.0' }

  # Mock application cache with cache fixture
  before do |example|
    allow(JavaBuildpack::Util::Cache::ApplicationCache).to receive(:new).and_return(application_cache)

    cache_fixture = example.metadata[:cache_fixture]
    if cache_fixture
      allow(application_cache).to receive(:get).with(uri)
        .and_yield(Pathname.new("spec/fixtures/#{cache_fixture}").open, false)
    end
  end

  # Mock repository
  before do
    tokenized_version = JavaBuildpack::Util::TokenizedVersion.new(version)

    allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item) do |&block|
      block.call(tokenized_version) if block
    end.and_return([tokenized_version, uri])
  end

end
