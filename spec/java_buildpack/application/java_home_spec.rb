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
require 'application_helper'

describe JavaBuildpack::Application::JavaHome do
  include_context 'application_helper'

  let(:java_home) { application.component_directory('test-java-home') }

  before do
    application.java_home.set java_home
  end

  it 'should set JAVA_HOME environment variable' do
    application.java_home.do_with { expect(ENV['JAVA_HOME']).to eq("$PWD/#{java_home.relative_path_from app_dir}") }
  end

end
