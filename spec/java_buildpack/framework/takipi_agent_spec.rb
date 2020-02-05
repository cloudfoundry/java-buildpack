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
require 'java_buildpack/framework/takipi_agent'

describe JavaBuildpack::Framework::TakipiAgent do
  include_context 'with component help'

  let(:configuration) { { 'node_name_prefix' => nil } }

  it 'does not detect without takipi-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/takipi/, %w[secret_key collector_host]).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with takipi service' do
      expect(component.detect).to eq("takipi-agent=#{version}")
    end

    it 'expands Takipi agent tarball',
       cache_fixture: 'stub-takipi-agent.tar.gz' do

      component.compile

      expect(sandbox + 'lib/libTakipiAgent.so').to exist
    end

    context do
      let(:credentials) { { 'collector_host' => 'test-host' } }

      it 'updates default environment variables' do
        component.release

        expect(environment_variables)
          .to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/.java-buildpack/takipi_agent/lib')
        expect(environment_variables).to include('JVM_LIB_FILE=$PWD/.test-java-home/lib/amd64/server/libjvm.so')
        expect(environment_variables).to include('TAKIPI_HOME=$PWD/.java-buildpack/takipi_agent')
      end

      it 'updates user environment variables' do
        component.release

        expect(environment_variables).to include('TAKIPI_COLLECTOR_HOST=test-host')
      end

      context 'with secret key' do
        let(:credentials) { super().merge 'secret_key' => 'test-key' }

        it 'secret key set' do
          component.release

          expect(environment_variables).to include('TAKIPI_SECRET_KEY=test-key')
        end
      end

      context 'with configuration overrides' do

        let(:configuration) { { 'node_name_prefix' => 'test-name', 'application_name' => 'test-name' } }

        it 'update application name' do
          component.release
          expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/takipi_agent/lib/libTakipiAgent.so')
          expect(java_opts).to include('-Dtakipi.name=test-name')
        end

      end
    end

  end

end
