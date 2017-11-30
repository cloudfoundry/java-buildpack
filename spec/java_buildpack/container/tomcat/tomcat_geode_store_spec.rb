# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
  include_context 'component_helper'

  let(:component_id) { 'tomcat' }

  let(:configuration) do
    { 'database'             => 'test-database',
      'timeout'              => 'test-timeout',
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
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect(sandbox + 'lib/stub-geode-store/stub-jar-1.jar').to exist
      expect(sandbox + 'lib/stub-geode-store/stub-jar-2.jar').to exist
    end

    it 'mutates context.xml',
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/context.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_context_after.xml').read)
    end

    it 'mutates server.xml',
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/server.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_server_after.xml').read)
    end

    it 'adds a cache-client.xml',
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.compile

      expect((sandbox + 'conf/cache-client.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_geode_store_cache_client_after.xml').read)
    end

    it 'passes security properties to the release',
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.release

      expect(java_opts).to include(
        '-Dgemfire.security-client-auth-init=io.pivotal.cloudcache.ClientAuthInitialize.create'
      )
      expect(java_opts).to include('-Dgemfire.security-username=some-username')
      expect(java_opts).to include('-Dgemfire.security-password=some-password')
    end
  end

  context 'when there is session replication service and service credentials do not include roles' do
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
                  'username' => 'cluster_operator'
                }
              ]
        }
      )
    end

    it 'assumes usernames represent roles and passes security properties to the release',
       app_fixture:   'container_tomcat_geode_store',
       cache_fixture: 'stub-geode-store.tar' do

      component.release

      expect(java_opts).to include(
        '-Dgemfire.security-client-auth-init=io.pivotal.cloudcache.ClientAuthInitialize.create'
      )
      expect(java_opts).to include('-Dgemfire.security-username=cluster_operator')
      expect(java_opts).to include('-Dgemfire.security-password=some-password')
    end
  end
end
