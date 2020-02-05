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
require 'java_buildpack/util/play/post22_dist'

describe JavaBuildpack::Util::Play::Post22Dist do
  include_context 'with component help'

  context do

    let(:trigger) { described_class.new(droplet).supports? }

    it 'does not recognize non-applications' do
      expect(trigger).not_to be_truthy
    end

    it 'does not recognize Play 2.0 applications',
       app_fixture: 'container_play_2.0_dist' do

      expect(trigger).not_to be_truthy
    end

    it 'does not recognize Play 2.1 dist applications',
       app_fixture: 'container_play_2.1_dist' do

      expect(trigger).not_to be_truthy
    end

    it 'does not recognize Play 2.1 staged applications',
       app_fixture: 'container_play_2.1_staged' do

      expect(trigger).not_to be_truthy
    end

    it 'does not recognize a Ratpack application',
       app_fixture: 'container_ratpack_dist' do

      expect(trigger).not_to be_truthy
    end

    it 'does not recognize a Spring Boot application',
       app_fixture: 'container_spring_boot_dist' do

      expect(trigger).not_to be_truthy
    end

    it 'does not recognize a distZip application',
       app_fixture: 'container_dist_zip' do

      expect(trigger).not_to be_truthy
    end

    it 'recognizes Play 2.2 dist applications',
       app_fixture: 'container_play_2.2_dist' do

      expect(trigger).to be_truthy
    end

    it 'does not recognize Play 2.2 staged applications',
       app_fixture: 'container_play_2.2_staged' do

      expect(trigger).not_to be_truthy
    end
  end

end
