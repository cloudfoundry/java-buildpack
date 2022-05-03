# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2021 the original author or authors.
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
require 'java_buildpack/container/tomcat/tomcat_geode_store'

describe JavaBuildpack::Container::TomcatGeodeStore do
  include_context 'with component help'

  let(:component) { described_class.new(context, '9') }

  let(:component_id) { 'tomcat' }

  let(:configuration) do
    { 'database' => 'test-database',
      'timeout' => 'test-timeout',
      'connection_pool_size' => 'test-connection-pool-size' }
  end

  it 'does not detect without a session-replication service' do
    expect(component.detect).to be_nil
  end

  context 'when there is a session-replication service' do
    before do
      allow(services).to receive(:one_service?).with(/session-replication/, 'locators', 'users')
                                               .and_return(true)
      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'locators' => ['some-locator[some-port]', 'some-other-locator[some-other-port]'],
          'users' =>
            [
              {
                'password' => 'some-password',
                'username' => 'some-username',
                'roles' => ['cluster_operator']
              }
            ]
        }
      )

    end

    it 'detect with a session-replication service' do
      expect(component.detect).to eq("tomcat-geode-store=#{version}")
    end

    it 'copies resources',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect(sandbox + 'lib/stub-jar-1.jar').to exist
      expect(sandbox + 'lib/stub-jar-2.jar').to exist
      expect(sandbox + 'lib/geode-modules-tomcat9.jar').to exist
    end

    it 'mutates context.xml',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/context.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_context_after.xml').read)
    end

    it 'prints warning when Tomcat version in buildpack is different from Geode Tomcat module version',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component = described_class.new(context, '8')

      expect { component.compile }.to output(
        # rubocop:disable Layout/LineLength
        /WARNING: Tomcat version 8 does not match Geode Tomcat 9 module\. If you encounter compatibility issues, please make sure these versions match\./
        # rubocop:enable Layout/LineLength
      ).to_stdout
    end

    it 'does not add Geode Tomcat module version to Session Manager classname if version is empty',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store-no-tomcat-version.tar' do

      component.compile

      expect((sandbox + 'conf/context.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_no_tomcat_version_geode_store_context_after.xml').read)
    end

    it 'raises runtime error if multiple Geode Tomcat module jars are detected',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store-tomcat-multi-version.tar' do

      # rubocop:disable Layout/LineLength
      expect { component.compile }.to raise_error RuntimeError, 'Multiple versions of geode-modules-tomcat jar found. Please verify your geode_store tar only contains one geode-modules-tomcat jar.'
      # rubocop:enable Layout/LineLength
    end

    it 'raises runtime error if no Geode Tomcat module jar is detected',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store-no-geode-tomcat.tar' do

      # rubocop:disable Layout/LineLength
      expect { component.compile }.to raise_error RuntimeError, 'Geode Tomcat module not found. Please verify your geode_store tar contains a geode-modules-tomcat jar.'
      # rubocop:enable Layout/LineLength
    end

    it 'mutates server.xml',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/server.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_server_after.xml').read)
    end

    it 'adds a cache-client.xml',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/cache-client.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_cache_client_after.xml').read)
    end

    it 'passes client auth class to the release',
       app_fixture: 'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.release

      expect(java_opts).to include(
        '-Dgemfire.security-client-auth-init=io.pivotal.cloudcache.ClientAuthInitialize.create'
      )
    end
  end
end
