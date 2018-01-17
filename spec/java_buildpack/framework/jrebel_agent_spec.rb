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
require 'java_buildpack/framework/jrebel_agent'

describe JavaBuildpack::Framework::JrebelAgent do
  include_context 'with component help'

  it 'does not detect when rebel-remote.xml is not present' do
    expect(component.detect).to be_nil
  end

  it 'detects when rebel-remote.xml is present in the top-level directory',
     app_fixture: 'framework_jrebel_app_simple' do

    expect(component.detect).to eq("jrebel-agent=#{version}")
  end

  it 'detects when rebel-remote.xml is present in WEB-INF/classes',
     app_fixture: 'framework_jrebel_app_war' do

    expect(component.detect).to eq("jrebel-agent=#{version}")
  end

  it 'detects when rebel-remote.xml is present inside an embedded JAR',
     app_fixture: 'framework_jrebel_app_war_with_jar' do

    expect(component.detect).to eq("jrebel-agent=#{version}")
  end

  context do
    let(:configuration) { { 'enabled' => false } }

    it 'does not detect when not enabled',
       app_fixture: 'framework_jrebel_app_simple' do

      expect(component.detect).to be_nil
    end
  end

  it 'downloads the JRebel JAR and the native agent',
     app_fixture:   'framework_jrebel_app_simple',
     cache_fixture: 'stub-jrebel-archive.zip' do

    component.compile

    expect(sandbox + 'lib/libjrebel64.so').to exist
    expect(sandbox + 'lib/libjrebel32.so').to exist
  end

  it 'adds correct arguments to JAVA_OPTS',
     app_fixture:   'framework_jrebel_app_simple',
     cache_fixture: 'stub-jrebel-archive.zip' do

    allow(component).to receive(:architecture).and_return('x86_64')

    component.release

    expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jrebel_agent/lib/libjrebel64.so')
    expect(java_opts).to include('-Drebel.remoting_plugin=true')
    expect(java_opts).to include('-Drebel.cloud.platform=cloudfoundry/java-buildpack')
  end

  it 'does not throw an error when a directory ends in .jar',
     app_fixture: 'framework_jrebel_jar_directory' do

    expect_any_instance_of(described_class).not_to receive(:`).with(start_with("unzip -l #{app_dir + 'directory.jar'}"))

    component.detect
  end

end
