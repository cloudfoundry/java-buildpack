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
require 'component_helper'
require 'java_buildpack/framework/sky_walking_agent'

describe JavaBuildpack::Framework::SkyWalkingAgent do
  include_context 'with component help'

  let(:configuration) do
    { 'default_application_name' => nil }
  end

  it 'does not detect without skywalking-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/sky[-]?walking/, 'servers').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with skywalking-n/a service' do
      expect(component.detect).to eq("sky-walking-agent=#{version}")
    end

    it 'expands Skywalking agent tar',
       cache_fixture: 'stub-skywalking-agent.tar.gz' do

      component.compile

      expect(sandbox + 'skywalking-agent.jar').to exist
    end

    it 'raises error if servers not specified' do
      expect { component.release }.to raise_error(/'servers' credential must be set/)
    end

    context do

      let(:credentials) { { 'servers' => 'test-servers' } }

      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/sky_walking_agent/skywalking-agent.jar')
        expect(java_opts).to include('-Dskywalking.collector.servers=test-servers')
        expect(java_opts).to include('-Dskywalking.agent.application_code=test-application-name')
      end

      context do
        let(:credentials) { super().merge 'sample-n-per-3-secs' => '10' }

        it 'adds sample_n_per_3_secs from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.agent.sample_n_per_3_secs=10')
        end
      end

      context do
        let(:credentials) { super().merge 'application-name' => 'another-test-application-name' }

        it 'adds application_name from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.agent.application_code=another-test-application-name')
        end
      end

      context do
        let(:credentials) { super().merge 'span-limit-per-segment' => '300' }

        it 'adds span_limit_per_segment from credentials to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.agent.span_limit_per_segment=300')
        end
      end

      context do
        let(:credentials) { super().merge 'ignore-suffix' => '.html' }

        it 'adds ignore_suffix to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.agent.ignore_suffix=.html')
        end
      end

      context do
        let(:credentials) { super().merge 'is-open-debugging-class' => 'true' }

        it 'adds is_open_debugging_class to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.agent.is_open_debugging_class=true')
        end
      end

      context do
        let(:credentials) { super().merge 'logging-level' => 'DEBUG' }

        it 'adds logging_level to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-Dskywalking.logging.level=DEBUG')
        end
      end
    end

  end

end
