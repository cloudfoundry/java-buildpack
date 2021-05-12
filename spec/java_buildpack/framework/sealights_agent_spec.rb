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
require 'java_buildpack/framework/sealights_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::SealightsAgent do
  include_context 'with component help'

  it 'does not detect without sealights service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { { 'token' => 'my_token' } }

    let(:configuration) do
      { 'build_session_id' => '1234',
        'proxy' => '127.0.0.1:8888',
        'lab_id' => 'lab1',
        'enable_upgrade' => true }
    end

    before do
      allow(services).to receive(:one_service?).with(/sealights/, 'token').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with sealights service' do
      expect(component.detect).to eq("sealights-agent=#{version}")
    end

    context do
      it 'updates JAVA_OPTS sl.tags' do
        component.release

        expect(java_opts).to include('-Dsl.tags=pivotal_cloud_foundry')
      end

      it 'updates JAVA_OPTS sl.buildSessionId' do
        component.release

        expect(java_opts).to include("-Dsl.buildSessionId=#{configuration['build_session_id']}")
      end

      it 'updates JAVA_OPTS sl.labId' do
        component.release

        expect(java_opts).to include("-Dsl.labId=#{configuration['lab_id']}")
      end

      it 'updates JAVA_OPTS sl.proxy' do
        component.release

        expect(java_opts).to include("-Dsl.proxy=#{configuration['proxy']}")
      end

      it 'updates JAVA_OPTS sl.enableUpgrade' do
        component.release

        expect(java_opts).to include("-Dsl.enableUpgrade=#{configuration['enable_upgrade']}")
      end

      it 'updates JAVA_OPTS sl.token' do
        component.release

        expect(java_opts).to include("-Dsl.token=#{credentials['token']}")
      end
    end

    context do
      let(:configuration) { {} }

      it 'does not specify JAVA_OPTS sl.buildSessionId if one was not specified' do
        component.release

        expect(java_opts).not_to include(/buildSessionId/)
      end

      it 'does not specify JAVA_OPTS sl.labId if one was not specified' do
        component.release

        expect(java_opts).not_to include(/labId/)
      end

      it 'does not specify JAVA_OPTS sl.proxy if one was not specified' do
        component.release

        expect(java_opts).not_to include(/proxy/)
      end

      it 'does not specify JAVA_OPTS sl.enableUpgrade if one was not specified' do
        component.release

        expect(java_opts).not_to include(/enableUpgrade/)
      end

    end

  end

end
