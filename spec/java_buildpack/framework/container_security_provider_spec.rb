# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

  let(:java_home) do
    java_home         = JavaBuildpack::Component::MutableJavaHome.new
    java_home.version = version_8
    return java_home
  end

  let(:version_8) { JavaBuildpack::Util::TokenizedVersion.new('1.8.0_162') }

  let(:version_9) { JavaBuildpack::Util::TokenizedVersion.new('9.0.4_11') }

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context 'when enabled' do

    let(:configuration) { { 'enabled' => true } }

    it 'detects if enabled' do
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

    context 'when java 9' do

      it 'adds JAR to classpath during compile in Java 9',
         cache_fixture: 'stub-container-security-provider.jar' do

        java_home.version = version_9

        component.compile

        expect(additional_libraries).to include(droplet.sandbox + "container_security_provider-#{version}.jar")
      end

      it 'adds JAR to classpath during release in Java 9' do
        java_home.version = version_9

        component.release

        expect(additional_libraries).to include(droplet.sandbox + "container_security_provider-#{version}.jar")
      end

      it 'adds does not add extension directory in Java 9' do
        java_home.version = version_9

        component.release

        expect(extension_directories).not_to include(droplet.sandbox)
      end

    end

  end

end
