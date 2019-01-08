# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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
require 'java_buildpack/container/play_framework'
require 'java_buildpack/util/play/factory'

describe JavaBuildpack::Container::PlayFramework do
  include_context 'with component help'

  let(:delegate) { instance_double('delegate') }

  context do

    before do
      allow(JavaBuildpack::Util::Play::Factory).to receive(:create).with(droplet).and_return(delegate)
    end

    it 'delegates detect' do
      allow(delegate).to receive(:version).and_return('0.0.0')

      expect(component.detect).to eq('play-framework=0.0.0')
    end

    it 'delegates compile' do
      allow(delegate).to receive(:compile)

      component.compile
    end

    it 'delegates release' do
      allow(delegate).to receive(:release)

      component.release
    end

  end

  context do

    before do
      allow(JavaBuildpack::Util::Play::Factory).to receive(:create).with(droplet).and_return(nil)
    end

    it 'does not delegate detect' do
      expect(component.detect).to be_nil
    end

    it 'does not delegate compile' do
      component.compile
    end

    it 'does not delegate release' do
      component.release
    end

  end

end
