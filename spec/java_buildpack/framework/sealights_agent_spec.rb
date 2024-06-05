# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2024 the original author or authors.
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
require 'java_buildpack/framework/sealights_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::SealightsAgent do
  include_context 'with component help'

  it 'does not detect without sealights service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { { 'token' => 'my_token' } }

    let(:configuration) do
      { 'build_session_id' => '1234',
        'proxy' => '127.0.0.1:8888',
        'lab_id' => 'lab1',
        'enable_upgrade' => true }
    end

    before do
      allow(services).to receive(:one_service?).with(/sealights/, 'token').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
      uri = 'https://test-apiurl/getcustomagent/agent.zip'
      p = Pathname.new('spec/fixtures/stub-sealights-custom-agent.zip')
      allow(application_cache).to receive(:get).with(uri).and_yield(p.open, false)
    end

    it 'detects with sealights service' do
      expect(component.detect).to eq("sealights-agent=#{version}")
    end

    context do
      it 'updates JAVA_OPTS sl.tags with buildpack version number' do
        allow_any_instance_of(JavaBuildpack::BuildpackVersion)
          .to receive(:to_hash).and_return({ 'version' => '1234',
                                             'offline' => false,
                                             'remote' => 'test-remote',
                                             'hash' => 'test-hash' })
        component.release

        expect(java_opts).to include('-Dsl.tags=sl-pcf-1234')
      end

      it 'updates JAVA_OPTS sl.tags with buildpack version number and offline info' do
        allow_any_instance_of(JavaBuildpack::BuildpackVersion)
          .to receive(:to_hash).and_return({ 'version' => '1234',
                                             'offline' => true,
                                             'remote' => 'test-remote',
                                             'hash' => 'test-hash' })
        component.release

        expect(java_opts).to include('-Dsl.tags=sl-pcf-1234\(offline\)')
      end

      it 'updates JAVA_OPTS sl.tags with version number' do
        allow_any_instance_of(JavaBuildpack::BuildpackVersion)
          .to receive(:to_hash).and_return({ 'version' => '1234',
                                             'remote' => 'test-remote',
                                             'hash' => 'test-hash' })
        component.release

        expect(java_opts).to include('-Dsl.tags=sl-pcf-1234')
      end

      it 'updates JAVA_OPTS sl.tags with information about unknown version number' do
        allow_any_instance_of(JavaBuildpack::BuildpackVersion).to receive(:to_hash).and_return({})
        component.release

        expect(java_opts).to include('-Dsl.tags=sl-pcf-v-unknown')
      end

      it 'updates JAVA_OPTS sl.buildSessionId' do
        component.release

        expect(java_opts).to include("-Dsl.buildSessionId=#{configuration['build_session_id']}")
      end

      it 'updates JAVA_OPTS sl.labId' do
        component.release

        expect(java_opts).to include("-Dsl.labId=#{configuration['lab_id']}")
      end

      it 'updates JAVA_OPTS sl.proxy' do
        component.release

        expect(java_opts).to include("-Dsl.proxy=#{configuration['proxy']}")
      end

      it 'updates JAVA_OPTS sl.enableUpgrade' do
        component.release

        expect(java_opts).to include("-Dsl.enableUpgrade=#{configuration['enable_upgrade']}")
      end

      it 'updates JAVA_OPTS sl.token' do
        component.release

        expect(java_opts).to include("-Dsl.token=#{credentials['token']}")
      end
    end

    context do
      let(:configuration) { {} }

      it 'does not specify JAVA_OPTS sl.buildSessionId if one was not specified' do
        component.release

        expect(java_opts).not_to include(/buildSessionId/)
      end

      it 'does not specify JAVA_OPTS sl.labId if one was not specified' do
        component.release

        expect(java_opts).not_to include(/labId/)
      end

      it 'does not specify JAVA_OPTS sl.proxy if one was not specified' do
        component.release

        expect(java_opts).not_to include(/proxy/)
      end

      it 'sets JAVA_OPTS sl.enableUpgrade to false by default' do
        component.release

        expect(java_opts).to include('-Dsl.enableUpgrade=false')
      end
    end

    context do
      let(:credentials) { { 'token' => 'my_token', 'proxy' => 'my_proxy', 'lab_id' => 'my_lab' } }
      let(:configuration) { {} }

      it 'updates JAVA_OPTS sl.labId from the user provisioned service' do
        component.release

        expect(java_opts).to include("-Dsl.labId=#{credentials['lab_id']}")
      end

      it 'updates JAVA_OPTS sl.proxy from the user provisioned service' do
        component.release

        expect(java_opts).to include("-Dsl.proxy=#{credentials['proxy']}")
      end
    end

    context do
      let(:credentials) { { 'token' => 'my_token', 'proxy' => 'my_proxy', 'lab_id' => 'my_lab' } }

      let(:configuration) do
        { 'proxy' => '127.0.0.1:8888',
          'lab_id' => 'lab1' }
      end

      it 'updates JAVA_OPTS sl.labId from config (and not user provisioned service)' do
        component.release

        expect(java_opts).to include("-Dsl.labId=#{configuration['lab_id']}")
      end

      it 'updates JAVA_OPTS sl.proxy from config (and not user provisioned service)' do
        component.release

        expect(java_opts).to include("-Dsl.proxy=#{configuration['proxy']}")
      end
    end

    context do
      let(:credentials) { { 'token' => 'my_token' } }

      let(:configuration) do
        { 'build_session_id' => '1234',
          'lab_id' => 'lab1',
          'enable_upgrade' => true,
          'customAgentUrl' => 'https://foo.com/getcustomagent/sealights-custom-agent.zip' }
      end

      before do
        allow(services).to receive(:one_service?).with(/sealights/, 'token').and_return(true)
        allow(services).to receive(:find_service).and_return('credentials' => credentials)
        uri = 'https://foo.com/getcustomagent/sealights-custom-agent.zip'
        p = Pathname.new('spec/fixtures/stub-sealights-custom-agent.zip')
        allow(application_cache).to receive(:get).with(uri).and_yield(p.open, false)
        allow(Net::HTTP).to receive(:start).with('foo.com', 443, use_ssl: true).and_call_original
        stub_request(:get, uri)
          .with(
            headers: {
              'Accept' => '*/*',
              'User-Agent' => 'Ruby'
            }
          ).to_return(status: 200, body: '', headers: {})

      end

      it 'downloads custom agent jar',
         cache_fixture: 'stub-sealights-custom-agent.zip' do
        component.compile
        expect(sandbox + 'sl-test-listener-4.0.1.jar').to exist
      end

      it 'customAgentUrl from app configuration overwrites enableUpgrade to false',
         cache_fixture: 'stub-sealights-custom-agent.zip' do
        component.compile
        component.release
        expect(java_opts).to include('-Dsl.enableUpgrade=false')
      end
    end

    context do
      let(:credentials) do
        { 'token' => 'my_token',
          'customAgentUrl' => 'https://foo.com/getcustomagent/sealights-custom-agent.zip' }
      end

      let(:configuration) do
        { 'build_session_id' => '1234',
          'lab_id' => 'lab1',
          'enable_upgrade' => true }
      end

      before do
        allow(services).to receive(:one_service?).with(/sealights/, 'token').and_return(true)
        allow(services).to receive(:find_service).and_return('credentials' => credentials)
        uri = 'https://foo.com/getcustomagent/sealights-custom-agent.zip'
        p = Pathname.new('spec/fixtures/stub-sealights-custom-agent.zip')
        allow(application_cache).to receive(:get).with(uri).and_yield(p.open, false)
        allow(Net::HTTP).to receive(:start).with('foo.com', 443, use_ssl: true).and_call_original
        stub_request(:get, uri)
          .with(
            headers: {
              'Accept' => '*/*',
              'User-Agent' => 'Ruby'
            }
          ).to_return(status: 200, body: '', headers: {})

      end

      it 'downloads custom agent jar based on service settings',
         cache_fixture: 'stub-sealights-custom-agent.zip' do
        component.compile
        expect(sandbox + 'sl-test-listener-4.0.1.jar').to exist
      end

      it 'customAgentUrl from service settings forces overwrites enableUpgrade to false',
         cache_fixture: 'stub-sealights-custom-agent.zip' do
        component.compile
        component.release
        expect(java_opts).to include('-Dsl.enableUpgrade=false')
      end
    end

    context do
      let(:credentials) { { 'token' => 'my_token' } }

      let(:configuration) do
        { 'build_session_id' => '1234',
          'lab_id' => 'lab1',
          'customAgentUrl' => 'https://foo.com/getcustomagent/sealights-custom-agent-invalid.zip' }
      end

      before do
        allow(services).to receive(:one_service?).with(/sealights/, 'token').and_return(true)
        allow(services).to receive(:find_service).and_return('credentials' => credentials)
        uri = 'https://foo.com/getcustomagent/sealights-custom-agent-invalid.zip'
        p = Pathname.new('spec/fixtures/stub-sealights-custom-agent-invalid.zip')
        allow(application_cache).to receive(:get).with(uri).and_yield(p.open, false)
        stub_request(:get, 'https://foo.com/getcustomagent/sealights-custom-agent-invalid.zip')
          .with(
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'User-Agent' => 'Ruby'
            }
          ).to_return(status: 200, body: '', headers: {})
      end

      it 'test listener agent jar not found in downloaded zip',
         cache_fixture: 'stub-sealights-custom-agent-invalid.zip' do
        component.compile
        expect { component.release }
          .to raise_error(RuntimeError,
                          /Failed to find jar which name starts with 'sl-test-listener' in downloaded zip/)
      end
    end

  end

end
