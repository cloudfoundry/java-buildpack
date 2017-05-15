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
require 'java_buildpack/framework/debug'

describe JavaBuildpack::Framework::Debug do
  include_context 'component_helper'

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => true } }

    it 'detects when enabled' do
      expect(component.detect).to eq('debug=8000')
    end

    it 'uses 8000 as the default port and does not suspend by default' do
      component.release
      expect(java_opts).to include('-agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=n')
    end
  end

  context do
    let(:configuration) { { 'enabled' => true, 'port' => 8001 } }

    it 'uses configured port' do
      component.release
      expect(java_opts).to include('-agentlib:jdwp=transport=dt_socket,server=y,address=8001,suspend=n')
    end
  end

  context do
    let(:configuration) { { 'enabled' => true, 'suspend' => true } }

    it 'uses configured suspend' do
      component.release
      expect(java_opts).to include('-agentlib:jdwp=transport=dt_socket,server=y,address=8000,suspend=y')
    end
  end

end
