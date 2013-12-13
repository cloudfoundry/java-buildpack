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
require 'java_buildpack/component/application'
require 'java_buildpack/component/services'
require 'yaml'

shared_context 'application_helper' do

  let(:app_dir) { Pathname.new Dir.mktmpdir }

  let(:application) do
    allow(ENV).to receive(:to_hash).and_return(environment)

    JavaBuildpack::Component::Application.new app_dir
  end

  let(:details) { application.details }

  let(:environment) do
    { 'test-key'      => 'test-value', 'VCAP_APPLICATION' => vcap_application.to_yaml,
      'VCAP_SERVICES' => vcap_services.to_yaml }
  end

  let(:services) { application.services }

  let(:vcap_application) { { 'application_name' => 'test-application-name' } }

  let(:vcap_services) do
    { 'test-service-n/a' => [{ 'name'        => 'test-service-name', 'label' => 'test-service-n/a',
                               'tags'        => ['test-service-tag'], 'plan' => 'test-plan',
                               'credentials' => { 'uri' => 'test-uri' } }] }
  end

  before do
    FileUtils.mkdir_p app_dir
  end

  before do |example|
    app_fixture = example.metadata[:app_fixture]
    FileUtils.cp_r "spec/fixtures/#{app_fixture.chomp}/.", app_dir if app_fixture

    application
  end

  after do
    FileUtils.rm_rf app_dir
  end

end
