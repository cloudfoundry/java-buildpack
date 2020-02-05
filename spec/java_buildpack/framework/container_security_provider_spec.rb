# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/framework/container_security_provider'

describe JavaBuildpack::Framework::ContainerSecurityProvider do
  include_context 'with component help'

  it 'always detects' do
    expect(component.detect).to eq("container-security-provider=#{version}")
  end

  it 'adds extension directory' do
    component.release

    expect(extension_directories).to include(droplet.sandbox)
  end

  it 'adds security provider',
     cache_fixture: 'stub-container-security-provider.jar' do

    component.compile
    expect(security_providers[1]).to eq('org.cloudfoundry.security.CloudFoundryContainerProvider')
  end

  context do

    let(:java_home_delegate) do
      delegate         = JavaBuildpack::Component::MutableJavaHome.new
      delegate.root    = app_dir + '.test-java-home'
      delegate.version = JavaBuildpack::Util::TokenizedVersion.new('9.0.0')

      delegate
    end

    it 'adds JAR to classpath during compile in Java 9',
       cache_fixture: 'stub-container-security-provider.jar' do

      component.compile

      expect(root_libraries).to include(droplet.sandbox + "container_security_provider-#{version}.jar")
    end

    it 'adds JAR to classpath during release in Java 9' do
      component.release

      expect(root_libraries).to include(droplet.sandbox + "container_security_provider-#{version}.jar")
    end

    it 'does not add extension directory in Java 9' do
      component.release

      expect(extension_directories).not_to include(droplet.sandbox)
    end

  end

  it 'does not manager system properties' do
    component.release

    expect(java_opts).not_to include('-Dorg.cloudfoundry.security.keymanager.enabled=false')
    expect(java_opts).not_to include('-Dorg.cloudfoundry.security.trustmanager.enabled=false')
  end

  context 'when KeyManager disabled' do
    let(:configuration) { { 'key_manager_enabled' => false } }

    it 'adds system property' do
      component.release

      expect(java_opts).to include('-Dorg.cloudfoundry.security.keymanager.enabled=false')
    end

  end

  context 'when TrustManager disabled' do
    let(:configuration) { { 'trust_manager_enabled' => false } }

    it 'adds system property' do
      component.release

      expect(java_opts).to include('-Dorg.cloudfoundry.security.trustmanager.enabled=false')
    end

  end

  context 'when KeyManager enabled' do
    let(:configuration) { { 'key_manager_enabled' => true } }

    it 'adds system property' do
      component.release

      expect(java_opts).to include('-Dorg.cloudfoundry.security.keymanager.enabled=true')
    end

  end

  context 'when TrustManager enabled' do
    let(:configuration) { { 'trust_manager_enabled' => true } }

    it 'adds system property' do
      component.release

      expect(java_opts).to include('-Dorg.cloudfoundry.security.trustmanager.enabled=true')
    end

  end

end
