# frozen_string_literal: true

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
require 'java_buildpack/framework/protect_app_security_provider'

describe JavaBuildpack::Framework::ProtectAppSecurityProvider do
  include_context 'with component help'

  it 'does not detect without protectapp-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/protectapp/, 'client', 'trusted_certificates').and_return(true)

      allow(services).to receive(:find_service).and_return(
        'credentials' => {
          'client' => {
            'certificate' => "-----BEGIN CERTIFICATE-----\ntest-client-cert\n-----END CERTIFICATE-----",
            'private_key' => "-----BEGIN RSA PRIVATE KEY-----\ntest-client-private-key\n-----END RSA PRIVATE KEY-----"
          },
          'trusted_certificates' => [
            "-----BEGIN CERTIFICATE-----\ntest-server-1-cert\n-----END CERTIFICATE-----",
            "-----BEGIN CERTIFICATE-----\ntest-server-2-cert\n-----END CERTIFICATE-----"
          ],
          'NAE_IP.1' => 'server_ip',
          'foo' => 'bar'
        }
      )
    end

    it 'detects with protectapp-n/a service' do
      expect(component.detect).to eq("protect-app-security-provider=#{version}")
    end

    it 'unpacks the protectapp zip',
       cache_fixture: 'stub-protect-app-security-provider.zip' do

      allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original
      allow(component).to receive(:shell).with(start_with('openssl pkcs12'))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importkeystore"))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importcert"))

      component.compile

      expect(sandbox + "ext/IngrianNAE-#{version}.jar").to exist
      expect(sandbox + 'ext/Ingrianlog4j-core-2.1.jar').to exist
      expect(sandbox + 'ext/Ingrianlog4j-api-2.1.jar').to exist
    end

    it 'adds security provider',
       cache_fixture: 'stub-protect-app-security-provider.zip' do

      allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original
      allow(component).to receive(:shell).with(start_with('openssl pkcs12'))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importkeystore"))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importcert"))

      component.compile

      expect(security_providers.last).to eq('com.ingrian.security.nae.IngrianProvider')
    end

    it 'copies resources',
       cache_fixture: 'stub-protect-app-security-provider.zip' do

      allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original
      allow(component).to receive(:shell).with(start_with('openssl pkcs12'))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importkeystore"))
      allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importcert"))

      component.compile

      expect(sandbox + 'IngrianNAE.properties').to exist
    end

    it 'adds extension directory' do
      component.release

      expect(extension_directories).to include(droplet.sandbox + 'ext')
    end

    it 'updates JAVA_OPTS with additional options' do
      component.release

      expect(java_opts).to include('-Dcom.ingrian.security.nae.IngrianNAE_Properties_Conf_Filename=' \
                                   '$PWD/.java-buildpack/protect_app_security_provider/IngrianNAE.properties')
      expect(java_opts).to include('-Dcom.ingrian.security.nae.Key_Store_Location=' \
                                   '$PWD/.java-buildpack/protect_app_security_provider/nae-keystore.jks')
      expect(java_opts).to include('-Dcom.ingrian.security.nae.Key_Store_Password=nae-keystore-password')
      expect(java_opts).to include('-Dcom.ingrian.security.nae.NAE_IP.1=server_ip')
      expect(java_opts).to include('-Dcom.ingrian.security.nae.foo=bar')

      expect(java_opts).not_to include(start_with('-Dcom.ingrian.security.nae.client'))
      expect(java_opts).not_to include(start_with('-Dcom.ingrian.security.nae.trusted_certificates'))
    end

    context do

      let(:java_home_delegate) do
        delegate         = JavaBuildpack::Component::MutableJavaHome.new
        delegate.root    = app_dir + '.test-java-home'
        delegate.version = JavaBuildpack::Util::TokenizedVersion.new('9.0.0')

        delegate
      end

      it 'adds JAR to classpath during compile in Java 9',
         cache_fixture: 'stub-protect-app-security-provider.zip' do

        allow(component).to receive(:shell).with(start_with('unzip -qq')).and_call_original
        allow(component).to receive(:shell).with(start_with('openssl pkcs12'))
        allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importkeystore"))
        allow(component).to receive(:shell).with(start_with("#{java_home.root}/bin/keytool -importcert"))

        component.compile

        expect(additional_libraries).to include(droplet.sandbox + "ext/IngrianNAE-#{version}.000.jar")
      end

      it 'adds JAR to classpath during release in Java 9' do
        component.release

        expect(additional_libraries).to include(droplet.sandbox + "ext/IngrianNAE-#{version}.000.jar")
      end

      it 'adds does not add extension directory in Java 9' do
        component.release

        expect(extension_directories).not_to include(droplet.sandbox + 'ext')
      end

    end

  end
end
