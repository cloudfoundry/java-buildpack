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
require 'java_buildpack/container/tomcat/tomcat_logging_support'

describe JavaBuildpack::Container::TomcatLoggingSupport do
  include_context 'with component help'

  let(:component_id) { 'tomcat' }

  it 'always detects' do
    expect(component.detect).to eq("tomcat-logging-support=#{version}")
  end

  it 'copies resources',
     cache_fixture: 'stub-logging-support.jar' do

    component.compile

    expect(sandbox + "bin/tomcat_logging_support-#{version}.jar").to exist
  end

  it 'creates setenv.sh',
     cache_fixture: 'stub-logging-support.jar' do

    component.compile

    expect(sandbox + 'bin/setenv.sh').to exist
    expect((sandbox + 'bin/setenv.sh').read).to eq <<~SH
      #!/bin/sh

      CLASSPATH=$CLASSPATH:#{(sandbox + "bin/tomcat_logging_support-#{version}.jar").relative_path_from(app_dir)}
    SH
  end

end
