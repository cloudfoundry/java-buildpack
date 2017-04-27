# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/framework/jmxtrans_agent'

describe JavaBuildpack::Framework::JmxtransAgent do
  include_context 'component_helper'

  let(:configuration) do
    { 'enabled' => true }
  end

  it 'does not detect without jmxtrans-n/a service' do
    expect(component.detect).to be_nil
  end

  context 'with jmxtrans-n/a service' do
    let(:credentials) do
      { host: nil, port: nil }
    end

    before do
      allow(services).to receive(:one_service?).with(/jmxtrans/, *%w(host port)).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    context 'when not enabled' do
      let(:configuration) do
        { 'enabled' => false }
      end

      it 'does not detect' do
        expect(component.detect).to be_nil
      end
    end

    it 'detects' do
      expect(component.detect).to eq("jmxtrans-agent=#{version}")
    end

    it 'downloads Jmxtrans agent JAR', cache_fixture: 'stub-jmxtrans-agent.jar' do
      component.compile
      expect(sandbox + "jmxtrans_agent-#{version}.jar").to exist
    end

    it 'copies resources', cache_fixture: 'stub-jmxtrans-agent.jar' do
      component.compile
      expect(sandbox + 'jmxtrans-agent.xml').to exist
    end

    it 'raises error if host not specified' do
      expect { component.release }.to raise_error(/'host', 'port', 'jmxtrans_prefix' credentials must be set/)
    end

    context 'with VCAP_SERVICES credentials available' do
      let(:credentials) { { 'host' => 'test-host', 'port' => '0000' } }

      it 'raises an error for missing credentials' do
        expect { component.release }.to raise_error(/'jmxtrans_prefix' credentials must be set/)
      end

      context 'with an agent prefix provided' do
        let(:credentials) do
          super().merge('jmxtrans_prefix' => 'test-prefix.')
        end

        it 'updates JAVA_OPTS' do
          component.release

          aggregate_failures do
            expect(java_opts).to include('-Dgraphite.host=test-host')
            expect(java_opts).to include('-Dgraphite.port=0000')
            expect(java_opts).to include('-Dgraphite.prefix=test-prefix.test-application-name.${CF_INSTANCE_INDEX}')
            precompiled = '-javaagent:' \
              "$PWD/.java-buildpack/jmxtrans_agent/jmxtrans_agent-#{version}.jar=" \
              '$PWD/.java-buildpack/jmxtrans_agent/jmxtrans-agent.xml'
            expect(java_opts).to include(precompiled)
          end
        end
      end
    end
  end
end
