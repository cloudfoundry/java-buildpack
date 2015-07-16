# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2015 the original author or authors.
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
      allow(services).to receive(:one_service?).with(/luna/,
                                                     'host',
                                                     'host-certificate',
                                                     'client-private-key',
                                                     'client-certificate').and_return(true)
      allow(services).to receive(:find_service)
                           .and_return('credentials' => { 'server'             => 'test-server',
                                                          'host'               => 'test-host',
                                                          'host-certificate'   => 'test-host-cert',
                                                          'client-private-key' => 'test-private-key',
                                                          'client-certificate' => 'test-client-cert' })
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

    it 'unpacks the luna jar',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'usr/safenet/lunaclient/lib/libCryptoki2_64.so').to exist
      expect(sandbox + 'usr/safenet/lunaclient/jsp/lib/stub.file').to exist
    end

    it 'write certificate files',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(sandbox + 'usr/safenet/lunaclient/cert/server/CAFile.pem').to exist
      expect(sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameCert.pem').to exist
      expect(sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameKey.pem').to exist

      check_file_contents(sandbox + 'usr/safenet/lunaclient/cert/server/CAFile.pem', 'test-host-cert')
      check_file_contents(sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameCert.pem', 'test-client-cert')
      check_file_contents(sandbox + 'usr/safenet/lunaclient/cert/client/ClientNameKey.pem', 'test-private-key')
    end

    it 'writes host information',
       cache_fixture: 'stub-luna-security-provider.tar' do

      component.compile

      expect(File.read(sandbox + 'Chrystoki.conf')).to include('ServerName00 = test-host')
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
                                   'luna_security_provider/usr/safenet/lunaclient/jsp/lib')
    end

    def check_file_contents(file, contents)
      expect(File.read(file)).to eq contents
    end

  end
end
