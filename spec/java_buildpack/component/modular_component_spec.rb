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
require 'java_buildpack/component/modular_component'

describe JavaBuildpack::Component::ModularComponent do
  include_context 'component_helper'

  let(:component) { StubModularComponent.new context }

  it 'fails if supports? is unimplemented' do
    expect { component.supports? }.to raise_error
  end

  context do

    before do
      allow_any_instance_of(StubModularComponent).to receive(:supports?).and_return(false)
    end

    it 'returns nil from detect if not supported' do
      expect(component.detect).to be_nil
    end

    it 'fails if methods are unimplemented' do
      expect { component.command }.to raise_error
      expect { component.sub_components(context) }.to raise_error
    end
  end

  context do

    let(:sub_component) { instance_double('sub_component') }

    before do
      allow_any_instance_of(StubModularComponent).to receive(:supports?).and_return(true)
      allow_any_instance_of(StubModularComponent).to receive(:sub_components).and_return([sub_component, sub_component])
    end

    it 'returns name and version string from detect if supported' do
      allow(sub_component).to receive(:detect).and_return('sub_component=test-version', 'sub_component=test-version-2')

      detected = component.detect

      expect(detected).to include('sub_component=test-version')
      expect(detected).to include('sub_component=test-version-2')
    end

    it 'calls compile on each sub_component' do
      allow(sub_component).to receive(:compile).twice

      component.compile
    end

    it 'calls release on each sub_component and then command' do
      allow(sub_component).to receive(:release).twice
      allow_any_instance_of(StubModularComponent).to receive(:command).and_return('test-command')

      expect(component.release).to eq('test-command')
    end
  end

end

class StubModularComponent < JavaBuildpack::Component::ModularComponent

  public :command, :sub_components, :supports?

end
