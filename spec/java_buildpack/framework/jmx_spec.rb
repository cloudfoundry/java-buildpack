# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/framework/jmx'

describe JavaBuildpack::Framework::Jmx do
  include_context 'with component help'

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => true } }

    it 'detects when enabled' do
      expect(component.detect).to eq('jmx=5000')
    end

    it 'uses 5000 as the default port' do
      component.release
      expect(java_opts).to include '-Djava.rmi.server.hostname=127.0.0.1'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.authenticate=false'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.ssl=false'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.port=5000'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.rmi.port=5000'
    end
  end

  context do
    let(:configuration) { { 'enabled' => true, 'port' => 5001 } }

    it 'uses configured port' do
      component.release
      expect(java_opts).to include '-Djava.rmi.server.hostname=127.0.0.1'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.authenticate=false'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.ssl=false'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.port=5001'
      expect(java_opts).to include '-Dcom.sun.management.jmxremote.rmi.port=5001'
    end
  end

end
