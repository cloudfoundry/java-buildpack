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
require 'java_buildpack/base_component'

module JavaBuildpack

  describe BaseComponent do

    let(:context) { { 'foo' => 'bar' } }

    let(:base_component) { StubBaseComponent.new 'test-name', context }

    it 'should assign component name to an instance variable' do
      expect(base_component.component_name).to eq('test-name')
    end

    it 'should assign context to an instance variable' do
      expect(base_component.context).to eq(context)
    end

    it 'should assign context items to instance variables' do
      expect(base_component.foo).to eq(context['foo'])
    end

    it 'should fail if methods are unimplemented' do
      expect { base_component.detect }.to raise_error
      expect { base_component.compile }.to raise_error
      expect { base_component.release }.to raise_error
    end

  end

  class StubBaseComponent < BaseComponent

    attr_reader :component_name, :context, :foo

  end

end
