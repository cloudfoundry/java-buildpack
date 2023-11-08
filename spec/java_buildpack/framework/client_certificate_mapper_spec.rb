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
require 'java_buildpack/framework/client_certificate_mapper'

describe JavaBuildpack::Framework::ClientCertificateMapper do
  include_context 'with component help'

  it 'always detects' do
    expect(component.detect).to eq("client-certificate-mapper=#{version}")
  end

  it 'adds the jar to the additional libraries during compile',
     cache_fixture: 'stub-client-certificate-mapper.jar' do

    component.compile

    expect(sandbox + "client_certificate_mapper-#{version}.jar").to exist
    expect(additional_libraries).to include(sandbox + "client_certificate_mapper-#{version}.jar")
    # version was not patched by the compile step
    expect(configuration).to eq({})
  end


  it 'configures client certificate mapper to download version 2.+ during compile of spring boot 3 app',
     app_fixture: 'framework_java_cf_boot_3',
     cache_fixture: 'stub-client-certificate-mapper.jar' do

    component.compile

    expect(sandbox + "client_certificate_mapper-#{version}.jar").to exist
    expect(additional_libraries).to include(sandbox + "client_certificate_mapper-#{version}.jar")
    # version of the dep. was forced to 2.+ by the compile step, because Spring Boot 3 was found
    expect(configuration).to eq({ 'version' => '2.+' })
  end

  context 'user forced javax to be used' do
    let(:configuration) { { 'javax_forced' => true } }
    it 'configures client certificate mapper to download version 1 during compile of spring boot 3 app ',
       app_fixture: 'framework_java_cf_boot_3',
       cache_fixture: 'stub-client-certificate-mapper.jar' do

      component.compile

      expect(sandbox + "client_certificate_mapper-#{version}.jar").to exist
      expect(additional_libraries).to include(sandbox + "client_certificate_mapper-#{version}.jar")
      # user prevented version 2.+, forcing javax
      expect(configuration).to eq({ 'javax_forced' => true })
    end
  end

  it 'adds the jar to the additional libraries during release',
     cache_fixture: 'stub-client-certificate-mapper.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "client_certificate_mapper-#{version}.jar")
  end

end
