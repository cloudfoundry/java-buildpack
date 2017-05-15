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
require 'droplet_helper'
require 'java_buildpack/component/environment_variables'

describe JavaBuildpack::Component::EnvironmentVariables do
  include_context 'droplet_helper'

  let(:variables) { described_class.new droplet.root }

  it 'adds a variable to the collection' do
    variables.add_environment_variable 'test-key', 'test-value'

    expect(variables).to include('test-key=test-value')
  end

  it 'adds a qualified variable value to the collection' do
    variables.add_environment_variable 'test-key', droplet.sandbox

    expect(variables).to include('test-key=$PWD/.java-buildpack/environment_variables')
  end

  it 'renders the collection as an environment variable' do
    variables.add_environment_variable 'test-key-2', 'test-value-2'
    variables.add_environment_variable 'test-key-1', 'test-value-1'

    expect(variables.as_env_vars).to eq('test-key-2=test-value-2 test-key-1=test-value-1')
  end

end
