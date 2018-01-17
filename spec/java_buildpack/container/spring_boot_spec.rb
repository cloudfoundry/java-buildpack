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
require 'java_buildpack/container/spring_boot'

describe JavaBuildpack::Container::SpringBoot do
  include_context 'with component help'

  it 'detects a dist Spring Boot application',
     app_fixture: 'container_spring_boot_dist' do

    expect(component.detect).to eq('spring-boot=1.0.0.RELEASE')
  end

  it 'detects a staged Spring Boot application',
     app_fixture: 'container_spring_boot_staged' do

    expect(component.detect).to eq('spring-boot=1.0.0.RELEASE')
  end

  it 'does not detect a non-Spring Boot application',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Ratpack application',
     app_fixture: 'container_ratpack_dist' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a distZip application',
     app_fixture: 'container_dist_zip' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Play application',
     app_fixture: 'container_play_2.2_dist' do

    expect(component.detect).to be_nil
  end

  it 'extends the classpath',
     app_fixture: 'container_spring_boot_staged' do

    component.compile

    expect((app_dir + 'bin/application').read)
      .to match 'CLASSPATH=\$APP_HOME/.additional_libs/test-jar-1.jar:\$APP_HOME/.additional_libs/test-jar-2.jar:'
  end

  it 'returns command',
     app_fixture: 'container_spring_boot_staged' do

    expect(component.release).to eq("#{env_vars_str} #{java_home.as_env_var} exec $PWD/bin/application")
  end

  def env_vars_str
    environment_variables.join(' ')
  end

  def java_opts_str
    "\"#{java_opts.join(' ')}\""
  end

end
