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
require 'application_helper'
require 'droplet_helper'
require 'java_buildpack/util/play/pre22'

describe JavaBuildpack::Util::Play::Pre22 do
  include_context 'with application help'
  include_context 'with droplet help'

  let(:play_app) { described_class.new(droplet) }

  it 'raises error if root method is unimplemented' do
    expect { play_app.send(:root) }.to raise_error "Method 'root' must be defined"
  end

end
