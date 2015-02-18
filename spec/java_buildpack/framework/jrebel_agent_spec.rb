# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/framework/jrebel_agent'

describe JavaBuildpack::Framework::JrebelAgent do
  include_context 'component_helper'

  it 'does not detect without JRebel config files present' do
    expect(component.detect).to be_nil
  end

  it 'detects with JRebel config files are present',
     app_fixture: 'framework_jrebel_app',
     cache_fixture: 'stub-jrebel-archive.zip' do
    expect(component.detect).to eq("jrebel-agent=#{version}")
  end

  it 'downloads JRebel agent JAR',
     app_fixture: 'framework_jrebel_app',
     cache_fixture: 'stub-jrebel-archive.zip' do

    component.compile

    expect(sandbox + "jrebel_agent-#{version}.jar").to exist
  end

  it 'updates JAVA_OPTS',
     app_fixture: 'framework_jrebel_app',
     cache_fixture: 'stub-jrebel-archive.zip' do
    allow(services).to receive(:find_service).and_return('credentials' => { 'licenseKey' => 'test-license-key' })

    component.release

    expect(java_opts).to include("-javaagent:$PWD/.java-buildpack/jrebel_agent/jrebel_agent-#{version}.jar")
    expect(java_opts).to include('-Drebel.remoting_plugin=true')
    expect(java_opts).to include("-Xbootclasspath/p:$PWD/.java-buildpack/jrebel_agent/jrebel_agent-#{version}.jar")
  end

end
