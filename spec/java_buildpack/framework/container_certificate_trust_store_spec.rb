# Encoding: utf-8
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
require 'java_buildpack/framework/container_certificate_trust_store'

describe JavaBuildpack::Framework::ContainerCertificateTrustStore do
  include_context 'component_helper'

  let(:ca_certificates) { Pathname.new('spec/fixtures/ca-certificates.crt') }

  let(:configuration) { { 'enabled' => true } }

  it 'detects with ca-certificates file' do
    allow(component).to receive(:ca_certificates).and_return(ca_certificates)

    expect(component.detect).to eq('container-certificate-trust-store=0.0.0')
  end

  context do
    let(:configuration) { { 'enabled' => false } }

    it 'does not detect when disabled' do
      allow(component).to receive(:ca_certificates).and_return(ca_certificates)

      expect(component.detect).to be_nil
    end
  end

  it 'creates truststore',
     cache_fixture: 'stub-container-customizer.jar' do

    allow(component).to receive(:ca_certificates).and_return(ca_certificates)
    allow(component).to receive(:shell).with("#{java_home.root}/bin/java -jar " \
                                             "#{sandbox}/container_certificate_trust_store-0.0.0.jar " \
                                             "--container-source #{ca_certificates} " \
                                             "--destination #{sandbox}/truststore.jks " \
                                             '--destination-password java-buildpack-trust-store-password ' \
                                             "--jre-source #{java_home.root}/lib/security/cacerts " \
                                             '--jre-source-password changeit')

    component.compile
  end

  it 'adds truststore properties' do
    component.release
    expect(java_opts).to include('-Djavax.net.ssl.trustStore=$PWD/.java-buildpack/container_certificate_trust_store/' \
                                 'truststore.jks')
    expect(java_opts).to include('-Djavax.net.ssl.trustStorePassword=java-buildpack-trust-store-password')
  end

end
