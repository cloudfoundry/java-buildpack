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
require 'java_buildpack/framework/seeker_security_provider'

describe JavaBuildpack::Framework::SeekerSecurityProvider do
  include_context 'with component help'

  it 'does not detect without seeker service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/seeker/i, 'seeker_server_url').and_return(true)

      allow(services).to receive(:find_service).and_return('credentials' => { 'seeker_server_url' =>
                                                                              'http://localhost' })

      allow(application_cache).to receive(:get).with('http://localhost/rest/api/latest/installers/agents/binaries/JAVA')
                                               .and_yield(Pathname.new('spec/fixtures/stub-seeker-agent.zip').open,
                                                          false)
    end

    it 'detects with seeker service' do
      expect(component.detect).to eq('seeker-security-provider')
    end

    it 'expands Seeker agent zip for agent direct download' do
      component.compile

      expect(sandbox + 'seeker-agent.jar').to exist
    end

    it 'updates JAVA_OPTS' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/seeker_security_provider/seeker-agent.jar')
      expect(environment_variables).to include('SEEKER_SERVER_URL=http://localhost')
    end

  end

end
