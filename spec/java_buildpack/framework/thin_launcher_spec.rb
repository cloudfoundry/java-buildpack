# Encoding: utf-8
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
require 'java_buildpack/framework/thin_launcher'

describe JavaBuildpack::Framework::ThinLauncher do
  include_context 'component_helper'

  it 'does not detect without wrapper class' do
    expect(component.detect).to be_nil
  end

  context do

    it 'detects with wrapper class', app_fixture: 'framework_thin_launcher' do
      expect(component.detect).to eq("thin-launcher")
    end

    it 'runs the wrapper class', app_fixture: 'framework_thin_launcher' do
      allow(component).to receive(:shell).with(/org.example.ThinJarWrapper --thin.dryrun/)
      component.compile
    end

    context do
      let(:configuration) { { 'arguments' => '--thin.root=.' } }

      it 'accepts command line arguments', app_fixture: 'framework_thin_launcher' do
        allow(component).to receive(:shell).with(/org.example.ThinJarWrapper --thin.dryrun --thin.root=./)
        component.compile
      end

    end

    it 'creates a lib directory', app_fixture: 'framework_thin_launcher' do
      allow(component).to receive(:shell).with(anything())
      component.compile
      expect(context[:droplet].root + "/lib").to exist
    end

  end

end
