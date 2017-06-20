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
require 'java_buildpack/framework/container_security_provider'

describe JavaBuildpack::Framework::ContainerSecurityProvider do
  include_context 'component_helper'

  it 'always detects' do
    expect(component.detect).to eq("container-security-provider=#{version}")
  end

  it 'adds extension directory' do
    component.release

    expect(extension_directories).to include(droplet.sandbox)
  end

  it 'adds security provider',
     cache_fixture: 'stub-container-security-provider.jar' do

    component.compile
    expect(security_providers[1]).to eq('org.cloudfoundry.security.CloudFoundryContainerProvider')
  end

end
