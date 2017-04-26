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
require 'java_buildpack/framework/play_framework_jpa_plugin'

describe JavaBuildpack::Framework::PlayFrameworkJPAPlugin do
  include_context 'component_helper'

  let(:configuration) { { 'enabled' => true } }

  it 'detects Play 2.0 application',
     app_fixture: 'framework_play_jpa_plugin_play20' do

    expect(component.detect).to eq("play-framework-jpa-plugin=#{version}")
  end

  context do
    let(:configuration) { { 'enabled' => false } }

    it 'does not detect if disabled',
       app_fixture: 'framework_play_jpa_plugin_play20' do

      expect(component.detect).to be_nil
    end
  end

  it 'detects staged application',
     app_fixture: 'framework_play_jpa_plugin_staged' do

    expect(component.detect).to eq("play-framework-jpa-plugin=#{version}")
  end

  it 'detects dist application',
     app_fixture: 'framework_play_jpa_plugin_dist' do

    expect(component.detect).to eq("play-framework-jpa-plugin=#{version}")
  end

  it 'does not detect non-JPA application',
     app_fixture: 'container_play_2.1_dist' do

    expect(component.detect).to be_nil
  end

  it 'downloads additional libraries',
     app_fixture:   'framework_play_jpa_plugin_dist',
     cache_fixture: 'stub-play-jpa-plugin.jar' do

    component.compile

    expect(sandbox + "play_framework_jpa_plugin-#{version}.jar").to exist
  end

  it 'adds to additional libraries',
     app_fixture:   'framework_play_jpa_plugin_dist',
     cache_fixture: 'stub-play-jpa-plugin.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "play_framework_jpa_plugin-#{version}.jar")
  end

end
