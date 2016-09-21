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
require 'component_helper'
require 'java_buildpack/container/tomcat/tomcat_gemfire_store'
require 'java_buildpack/container/tomcat/gemfire/gemfire'
require 'java_buildpack/container/tomcat/gemfire/gemfire_logging'
require 'java_buildpack/container/tomcat/gemfire/gemfire_logging_api'
require 'java_buildpack/container/tomcat/gemfire/gemfire_modules'
require 'java_buildpack/container/tomcat/gemfire/gemfire_modules_tomcat7'
require 'java_buildpack/container/tomcat/gemfire/gemfire_security'

describe JavaBuildpack::Container::TomcatGemfireStore do
  include_context 'component_helper'

  let(:component_id) { 'tomcat' }

  let(:component) { StubGemfireStore.new context }

  let(:configuration) do
    { 'gemfire'                 => gemfire_configuration,
      'gemfire_modules'         => gemfire_modules_configuration,
      'gemfire_modules_tomcat7' => gemfire_modules_tomcat7_configuration,
      'gemfire_security'        => gemfire_security_configuration,
      'gemfire_logging'         => gemfire_logging_configuration,
      'gemfire_logging_api'     => gemfire_logging_api_configuration }
  end

  let(:gemfire_configuration) { instance_double('gemfire-configuration') }

  let(:gemfire_modules_configuration) { instance_double('gemfire-modules-configuration') }

  let(:gemfire_modules_tomcat7_configuration) { instance_double('gemfire-modules_tomcat7-configuration') }

  let(:gemfire_security_configuration) { instance_double('gemfire-security-configuration') }

  let(:gemfire_logging_configuration) { instance_double('gemfire-logging-configuration') }

  let(:gemfire_logging_api_configuration) { instance_double('gemfire-logging-api-configuration') }

  it 'does not detect without a session_replication service' do
    expect(component.detect).to be_nil
  end

  it 'does nothing without a session_replication service during release' do
    expect(component.command).to be_nil
  end

  it 'creates submodules' do
    allow(JavaBuildpack::Container::GemFire)
      .to receive(:new).with(sub_configuration_context(gemfire_configuration))
    allow(JavaBuildpack::Container::GemFireModules)
      .to receive(:new).with(sub_configuration_context(gemfire_modules_configuration))
    allow(JavaBuildpack::Container::GemFireModulesTomcat7)
      .to receive(:new).with(sub_configuration_context(gemfire_modules_tomcat7_configuration))
    allow(JavaBuildpack::Container::GemFireSecurity)
      .to receive(:new).with(sub_configuration_context(gemfire_security_configuration))
    allow(JavaBuildpack::Container::GemFireLogging)
      .to receive(:new).with(sub_configuration_context(gemfire_logging_configuration))
    allow(JavaBuildpack::Container::GemFireLoggingApi)
      .to receive(:new).with(sub_configuration_context(gemfire_logging_api_configuration))

    component.sub_components context
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/session_replication/, 'locators', 'username', 'password')
        .and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => { 'locators' => %w(1.0.0.2[45] 1.0.0.4[54]),
                                                                              'username' => 'test-username',
                                                                              'password' => 'test-password' })
      allow(application_cache).to receive(:get).with('test-uri').and_return('f')
    end

    it 'detect with a session_replication service' do
      expect(component.detect).to be
    end

    # rubocop:disable Metrics/LineLength
    it 'returns command' do
      expect(component.command).to eq(%w(test-opt-2
                                         test-opt-1
                                         -Dgemfire.security-username=test-username
                                         -Dgemfire.security-password=test-password
                                         -Dgemfire.security-client-auth-init=templates.security.UserPasswordAuthInit.create))
    end
    # rubocop:enable Metrics/LineLength

    it 'mutates context.xml',
       app_fixture: 'container_tomcat_gemfire_store' do
      component.compile
      expect((sandbox + 'conf/context.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_gemfire_store_context_after.xml').read)
    end

    it 'mutates server.xml',
       app_fixture: 'container_tomcat_gemfire_store' do
      component.compile
      expect((sandbox + 'conf/server.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_gemfire_store_server_after.xml').read)
    end

    it 'creates cache-client.xml',
       app_fixture: 'container_tomcat_gemfire_store' do
      component.compile
      expect((sandbox + 'conf/cache-client.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_gemfire_store_cache_client_after.xml').read)
    end

  end

end

class StubGemfireStore < JavaBuildpack::Container::TomcatGemfireStore
  public :command, :sub_components, :supports?
end

def sub_configuration_context(configuration)
  c                 = context.clone
  c[:configuration] = configuration
  c
end
