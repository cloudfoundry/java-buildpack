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
require 'console_helper'
require 'droplet_helper'
require 'java_buildpack/util/play/factory'

describe JavaBuildpack::Util::Play::Factory do
  include_context 'with console help'
  include_context 'with droplet help'

  let(:trigger) { described_class.create(droplet) }

  it 'creates a Play 2.0 application',
     app_fixture: 'container_play_2.0_dist' do

    trigger
  end

  it 'creates a Play 2.1 application',
     app_fixture: 'container_play_2.1_staged' do

    trigger
  end

  it 'creates a Play 2.2 application',
     app_fixture: 'container_play_2.2_staged' do

    trigger
  end

  it 'fails to create an application which is a hybrid of Play 2.1 and 2.2',
     app_fixture: 'container_play_2.1_2.2_hybrid' do

    expect { trigger }.to raise_error(/Play Framework application version cannot be determined/)
  end

end
