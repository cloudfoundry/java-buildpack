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
require 'java_buildpack/framework/dyadic_ekm_security_provider'

describe JavaBuildpack::Framework::DyadicEkmSecurityProvider do
  include_context 'component_helper'

  it 'does not detect without dyadic-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?)
        .with(/dyadic/, 'ca', 'key', 'recv_timeout', 'retries', 'send_timeout', 'servers')
        .and_return(true)

      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'ca'           => "-----BEGIN CERTIFICATE-----\ntest-client-cert\n-----END CERTIFICATE-----",
          'key'          => "-----BEGIN RSA PRIVATE KEY-----\ntest-client-private-key\n-----END RSA PRIVATE KEY-----",
          'recv_timeout' => 1,
          'retries'      => 2,
          'send_timeout' => 3,
          'servers'      => 'server-1,server-2'
        }
      )
    end

    it 'detects with dyadic-n/a service' do
      expect(component.detect).to eq("dyadic-ekm-security-provider=#{version}")
    end

    it 'unpacks the dyadic tar',
       cache_fixture: 'stub-dyadic-ekm-security-provider.tar.gz' do

      component.compile

      expect(sandbox + 'usr/lib/dsm/dsm-advapi-1.0.jar').to exist
      expect(sandbox + 'usr/lib').to exist
    end

    it 'write certificate and key files',
       cache_fixture: 'stub-dyadic-ekm-security-provider.tar.gz' do

      component.compile

      expect(sandbox + 'etc/dsm/ca.crt').to exist
      expect(sandbox + 'etc/dsm/key.pem').to exist

      check_file_contents(sandbox + 'etc/dsm/ca.crt',
                          'spec/fixtures/framework_dyadic_ekm_security_provider/ca.crt')
      check_file_contents(sandbox + 'etc/dsm/key.pem',
                          'spec/fixtures/framework_dyadic_ekm_security_provider/key.pem')
    end

    it 'writes configuration',
       cache_fixture: 'stub-dyadic-ekm-security-provider.tar.gz' do

      component.compile

      expect(sandbox + 'etc/dsm/client.conf').to exist
      check_file_contents(sandbox + 'etc/dsm/client.conf',
                          'spec/fixtures/framework_dyadic_ekm_security_provider/client.conf')
    end

    it 'updates environment variables' do
      component.release
      expect(environment_variables).to include('LD_LIBRARY_PATH=$PWD/.java-buildpack/' \
                                               'dyadic_ekm_security_provider/usr/lib')
    end

    it 'adds security provider',
       cache_fixture: 'stub-dyadic-ekm-security-provider.tar.gz' do

      component.compile

      expect(security_providers.last).to eq('com.dyadicsec.provider.DYCryptoProvider')
    end

    it 'adds extension directory' do
      component.release

      expect(extension_directories).to include(droplet.sandbox + 'ext')
    end

    def check_file_contents(actual, expected)
      expect(File.read(actual)).to eq File.read(expected)
    end

  end
end
