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
require 'java_buildpack/framework/luna_security_provider'

describe JavaBuildpack::Framework::LunaSecurityProvider do
  include_context 'component_helper'

  it 'does not detect without luna-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/luna/, 'client', 'servers', 'groups').and_return(true)

      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'client' => {
            'certificate' => "-----BEGIN CERTIFICATE-----\ntest-client-cert\n-----END CERTIFICATE-----",
            'private-key' => "-----BEGIN RSA PRIVATE KEY-----\ntest-client-private-key\n-----END RSA PRIVATE KEY-----"
          },
          'servers' => [
            {
              'name'        => 'test-server-1',
              'certificate' => "-----BEGIN CERTIFICATE-----\ntest-server-1-cert\n-----END CERTIFICATE-----"
            }, {
              'name'        => 'test-server-2',
              'certificate' => "-----BEGIN CERTIFICATE-----\ntest-server-2-cert\n-----END CERTIFICATE-----"
            }
          ],
          'groups' => [
            {
              'label'   => 'test-group-1',
              'members' => %w(test-group-1-member-1 test-group-1-member-2)
            }, {
              'label'   => 'test-group-2',
              'members' => %w(test-group-2-member-1 test-group-2-member-2)
            }
          ]
        }
      )
    end

    it 'detects with luna-n/a service' do
      expect(component.detect).to eq("luna-security-provider=#{version}")
    end

    it 'copies resources',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'Chrystoki.conf').to exist
      expect(sandbox + 'java.security').to exist
    end

    it 'unpacks the luna tar',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'libs/64/libCryptoki2.so').to exist
      expect(sandbox + 'libs/64/libcklog2.so').to exist
      expect(sandbox + 'jsp/LunaProvider.jar').to exist
      expect(sandbox + 'jsp/64/libLunaAPI.so').to exist
    end

    it 'write certificate files',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'client-certificate.pem').to exist
      expect(sandbox + 'client-private-key.pem').to exist
      expect(sandbox + 'server-certificates.pem').to exist

      check_file_contents(sandbox + 'client-certificate.pem',
                          'spec/fixtures/framework_luna_security_provider/client-certificate.pem')
      check_file_contents(sandbox + 'client-private-key.pem',
                          'spec/fixtures/framework_luna_security_provider/client-private-key.pem')
      check_file_contents(sandbox + 'server-certificates.pem',
                          'spec/fixtures/framework_luna_security_provider/server-certificates.pem')
    end

    it 'writes configuration',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'Chrystoki.conf').to exist
      check_file_contents(sandbox + 'Chrystoki.conf', 'spec/fixtures/framework_luna_security_provider/Chrystoki.conf')
    end

    it 'updates environment variables' do
      component.release
      expect(environment_variables).to include('ChrystokiConfigurationPath=$PWD/.java-buildpack/luna_security_provider')
    end

    it 'updates JAVA_OPTS' do
      component.release
      expect(java_opts).to include('-Djava.security.properties=$PWD/.java-buildpack/' \
                                   'luna_security_provider/java.security')
      expect(java_opts).to include('-Djava.ext.dirs=$PWD/.test-java-home/lib/ext:$PWD/.java-buildpack/' \
                                   'luna_security_provider/ext')
    end

    context do
      let(:configuration) { { 'logging_enabled' => true } }

      it 'writes configuration',
         cache_fixture: 'stub-luna-security-provider.tar' do

        component.compile

        expect(sandbox + 'Chrystoki.conf').to exist
        check_file_contents(sandbox + 'Chrystoki.conf',
                            'spec/fixtures/framework_luna_security_provider_logging/Chrystoki.conf')
      end
    end

    def check_file_contents(actual, expected)
      expect(File.read(actual)).to eq File.read(expected)
    end

  end
end
