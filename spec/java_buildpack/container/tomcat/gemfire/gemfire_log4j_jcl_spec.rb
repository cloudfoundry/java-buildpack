# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/container/tomcat/gemfire/gemfire_log4j_jcl'

describe JavaBuildpack::Container::GemFireLog4jJcl do
  include_context 'component_helper'

  let(:component_id) { 'tomcat' }

  it 'always detects' do
    expect(component.detect).to eq("gem-fire-log4j-jcl=#{version}")
  end

  it 'copies resources',
     cache_fixture: 'stub-gemfire-log4j-jcl.jar' do

    component.compile

    expect(sandbox + "lib/log4j-jcl-#{version}.jar").to exist
  end

  it 'does nothing during release' do
    component.release
  end

end
