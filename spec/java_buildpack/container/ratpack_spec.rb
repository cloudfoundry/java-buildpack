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
require 'java_buildpack/container/ratpack'

describe JavaBuildpack::Container::Ratpack do
  include_context 'with component help'

  it 'detects a dist Ratpack application',
     app_fixture: 'container_ratpack_dist' do

    expect(component.detect).to eq('ratpack=0.9.0')
  end

  it 'detects a staged Ratpack application',
     app_fixture: 'container_ratpack_staged' do

    expect(component.detect).to eq('ratpack=0.9.0')
  end

  it 'does not detect a non-Ratpack application',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Spring Boot application',
     app_fixture: 'container_spring_boot_dist' do

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
     app_fixture: 'container_ratpack_staged' do

    component.compile

    expect((app_dir + 'bin/application').read)
      .to match 'CLASSPATH=\$APP_HOME/.additional_libs/test-jar-1.jar:\$APP_HOME/.additional_libs/test-jar-2.jar:'
  end

  it 'returns command',
     app_fixture: 'container_ratpack_staged' do

    expect(component.release).to eq("test-var-2 test-var-1 JAVA_OPTS=$JAVA_OPTS #{java_home.as_env_var} exec " \
                                    '$PWD/bin/application')
  end

end
