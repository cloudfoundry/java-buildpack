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
require 'logging_helper'
require 'java_buildpack/framework/java_cf_env'

describe JavaBuildpack::Framework::JavaCfEnv do
  include_context 'with component help'
  include_context 'with console help'
  include_context 'with logging help'

  let(:configuration) { { 'enabled' => true } }

  it 'detects with Spring Boot 3 JAR',
     app_fixture: 'framework_java_cf_boot_3' do

    expect(component.detect).to eq("java-cf-env=#{version}")
  end

  it 'does not detect with Spring Boot < 3',
     app_fixture: 'framework_java_cf_boot_2' do

    expect(component.detect).to be_nil
  end

  it 'does not detect with Spring Boot 3 & java-cfenv present',
     app_fixture: 'framework_java_cf_exists' do

    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => false } }

    it 'does not detect if disabled',
       app_fixture: 'framework_java_cf_boot_3' do

      expect(component.detect).to be_nil
    end
  end

  it 'downloads additional libraries',
     app_fixture: 'framework_java_cf_boot_3',
     cache_fixture: 'stub-java-cfenv.jar' do

    component.compile

    expect(sandbox + "java_cf_env-#{version}.jar").to exist
  end

  it 'adds to additional libraries',
     app_fixture: 'framework_java_cf_boot_3',
     cache_fixture: 'stub-java-cfenv.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "java_cf_env-#{version}.jar")
  end

  it 'activates the cloud profile',
     app_fixture: 'framework_java_cf_boot_3',
     cache_fixture: 'stub-java-cfenv.jar' do

    component.release

    expect(environment_variables).to include('SPRING_PROFILES_INCLUDE=$SPRING_PROFILES_INCLUDE,cloud')
  end
end
