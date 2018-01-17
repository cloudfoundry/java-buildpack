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
require 'java_buildpack/framework/container_customizer'

describe JavaBuildpack::Framework::ContainerCustomizer do
  include_context 'with component help'

  it 'does not detect without Spring Boot WAR' do
    expect(component.detect).to be_nil
  end

  it 'detects with Spring Boot WAR',
     app_fixture: 'framework_container_customizer' do

    expect(component.detect).to eq("container-customizer=#{version}")
  end

  it 'downloads the container customizer',
     app_fixture: 'framework_container_customizer',
     cache_fixture: 'stub-container-customizer.jar' do

    component.compile

    expect(sandbox + "container_customizer-#{version}.jar").to exist
  end

  it 'adds container customizer to the additional libraries',
     app_fixture: 'framework_container_customizer',
     cache_fixture: 'stub-container-customizer.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "container_customizer-#{version}.jar")
  end

end
