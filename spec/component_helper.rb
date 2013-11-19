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
require 'additional_libs_helper'
require 'application_helper'
require 'console_helper'
require 'diagnostics_helper'
require 'fileutils'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/tokenized_version'
require 'pathname'
require 'tmpdir'

shared_context 'component_helper' do

  let(:application_cache) { double('ApplicationCache') }
  let(:configuration) { {} }
  let(:java_home) { 'test-java-home' }
  let(:java_opts) { %w(test-opt-2 test-opt-1) }
  let(:service_credentials) { {} }
  let(:service_payload) { [{ 'credentials' => service_credentials }] }
  let(:uri) { 'test-uri' }
  let(:vcap_application) { { 'application_name' => 'test-application-name' } }
  let(:version) { '0.0.0' }

  let(:component) do
    described_class.new(
        app_dir: app_dir,
        application: application,
        java_home: java_home,
        java_opts: java_opts,
        lib_directory: additional_libs_dir,
        configuration: configuration,
        vcap_application: vcap_application,
        vcap_services: vcap_services
    )
  end

  let(:vcap_services) do |example|
    vcap_services = {}

    service_type = example.metadata[:service_type]
    vcap_services[service_type] = service_payload if service_type

    vcap_services
  end

  include_context 'console_helper'

  # Mock application cache with cache fixture
  before do |example|
    allow(JavaBuildpack::Util::ApplicationCache).to receive(:new).and_return(application_cache)

    cache_fixture = example.metadata[:cache_fixture]
    allow(application_cache).to receive(:get).with(uri)
                                .and_yield(File.open("spec/fixtures/#{cache_fixture}")) if cache_fixture
  end

  # Mock repository
  before do
    tokenized_version = JavaBuildpack::Util::TokenizedVersion.new(version)

    allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item) do |&block|
      block.call(tokenized_version) if block
    end.and_return([tokenized_version, uri])
  end

  include_context 'application_helper'

  include_context 'additional_libs_helper'

  include_context 'diagnostics_helper'

  ############
  # Run test #
  ############

  # Reset cache
  after do
    JavaBuildpack::Util::DownloadCache.clear_internet_availability
  end

end
