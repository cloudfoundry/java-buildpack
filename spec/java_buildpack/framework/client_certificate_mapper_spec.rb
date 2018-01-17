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
  end

  it 'adds the jar to the additional libraries during release',
     cache_fixture: 'stub-client-certificate-mapper.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "client_certificate_mapper-#{version}.jar")
  end

end
