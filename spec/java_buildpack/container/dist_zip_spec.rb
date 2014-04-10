# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/container/dist_zip'

describe JavaBuildpack::Container::DistZip do
  include_context 'component_helper'

  it 'should not recognize non-applications' do
    expect(component.detect).not_to be
  end

  it 'should not recognize Play dist applications',
     app_fixture: 'container_play_2.2_dist' do

    expect(component.detect).not_to be
  end

  it 'should not recognize Play dist applications',
     app_fixture: 'container_play_2.2_staged' do

    expect(component.detect).not_to be
  end

  it 'should recognize distZip applications',
     app_fixture: 'container_dist_zip' do

    expect(component.detect).to eq('dist-zip')
  end

  it 'should correctly extend the CLASSPATH-style classpath',
     app_fixture: 'container_dist_zip' do

    component.compile

    expect((app_dir + 'dist-zip-application/bin/dist-zip-application').read)
    .to match 'CLASSPATH=\$APP_HOME/../.additional_libs/test-jar-1.jar:\$APP_HOME/../.additional_libs/test-jar-2.jar:'
  end

  it 'should correctly extend the app_classpath-style classpath',
     app_fixture: 'container_dist_zip_app_classpath' do

    component.compile

    expect((app_dir + 'dist-zip-application/bin/dist-zip-application').read)
    .to match 'declare -r app_classpath="\$app_home/../../.additional_libs/test-jar-1.jar:\$app_home/../../.additional_libs/test-jar-2.jar:'
  end

  it 'should return command',
     app_fixture: 'container_dist_zip' do

    expect(component.release).to eq("#{java_home.as_env_var} JAVA_OPTS=\"test-opt-2 test-opt-1\" SERVER_PORT=$PORT " \
    '$PWD/dist-zip-application/bin/dist-zip-application')
  end

end
