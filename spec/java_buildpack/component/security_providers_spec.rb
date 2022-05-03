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
require 'droplet_helper'
require 'java_buildpack/component/security_providers'

describe JavaBuildpack::Component::SecurityProviders do
  include_context 'with droplet help'

  context do

    before do
      security_providers.clear
    end

    it 'contains an added provider' do
      security_providers << 'test-security-provider'

      expect(security_providers).to include('test-security-provider')
    end
  end

  it 'symbolically links additional libraries' do
    security_file = app_dir + 'java.security'

    security_providers.write_to security_file

    expect(security_file.read).to eq("security.provider.1=test-security-provider-1\n" \
                                     "security.provider.2=test-security-provider-2\n")
  end

end
