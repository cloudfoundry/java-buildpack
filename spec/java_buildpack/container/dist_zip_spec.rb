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
require 'java_buildpack/container/dist_zip'

describe JavaBuildpack::Container::DistZip do
  include_context 'component_helper'

  it 'detects a distZip application',
     app_fixture: 'container_dist_zip' do

    expect(component.detect).to eq('dist-zip')
  end

  it 'does not detect a non-distZip application',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Ratpack application',
     app_fixture: 'container_ratpack_dist' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Spring Boot application',
     app_fixture: 'container_spring_boot_dist' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Play application',
     app_fixture: 'container_play_2.2_dist' do

    expect(component.detect).to be_nil
  end

end
