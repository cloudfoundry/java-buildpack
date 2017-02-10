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
require 'java_buildpack/framework/pa_security_provider'

describe JavaBuildpack::Framework::ProtectAppSecurityProvider do
  include_context 'component_helper'

  it 'does not detect without protectapp-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/protectapp/, 'client', 'trustedcerts').and_return(true)

    end

    it 'detects with protectapp-n/a service' do
      expect(component.detect).to eq("protectapp-security-provider=#{version}")
    end

    it 'copies resources',
       cache_fixture: 'stub-protectapp-security-provider.zip' do

      component.compile

      expect(sandbox + 'IngrianNAE.properties').to exist
    end

    it 'unpacks the protectapp zip',
       cache_fixture: 'stub-protectapp-security-provider.zip' do

      component.compile

      expect(sandbox + 'IngrianNAE-#{version}.jar').to exist
      expect(sandbox + 'Ingrianlog4j-core-2.1.jar').to exist
      expect(sandbox + 'Ingrianlog4j-api-2.1.jar').to exist
    end

    it 'write certificate files',
       cache_fixture: 'stub-protectapp-security-provider.zip' do

      component.compile

	  expect(sandbox + 'client-certificate.pem').to exist
      expect(sandbox + 'client-private-key.pem').to exist
	  expect(sandbox + 'trusted_certificates.pem').to exist
	 expect(sandbox + 'clientwrap.p12').to exist
	  
	 # transfer to keystore
	 expect(sandbox + 'keystore.jks').to exist

    end
	

    it 'updates JAVA_OPTS with additional options' do
      allow(services).to receive(:find_service).and_return('credentials' => { '#{NAE_IP.1}' => 'server_ip',
                                                                              '#{foo}' => 'bar' })

      component.release

      expect(java_opts).to include('-Dcom.ingrian.security.nae.NAE_IP.1=server_ip')
      expect(java_opts).to include('-Dcom.ingrian.security.nae.foo=bar')
    end

  end
end
