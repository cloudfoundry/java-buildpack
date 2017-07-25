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
require 'java_buildpack/framework/takipi_agent'
require 'java_buildpack/util/find_single_directory'

describe JavaBuildpack::Framework::TakipiAgent do
  include_context 'component_helper'

  context do
    let(:configuration) do
      {
        'uri' => 'test-uri',
        'secret_key' => 'test-secret',
        'collector_host' => 'test-host',
        'collector_port' => 'test-port'
      }
    end

    it 'expands Takipi agent tarball',
       cache_fixture: 'stub-takipi-agent.tar.gz' do

      component.compile

      expect(sandbox + 'lib/libTakipiAgent.so').to exist
    end

    it 'preserves find_single_directory results',
       cache_fixture: 'stub-takipi-agent.tar.gz',
       app_fixture: 'container_play_2.1_dist' do
      component.compile
      component.send(:extend, JavaBuildpack::Util)
      expect(component.send(:find_single_directory)).not_to be_nil
    end

    it 'updates JAVA_OPTS' do
      component.release
      expect(java_opts).to include('-agentlib:TakipiAgent')
      expect(java_opts).to include('-Dtakipi.name=test-application-name')
    end

    it 'updates default environment variables' do
      component.release

      expect(environment_variables).to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/.java-buildpack/takipi_agent/lib')
      expect(environment_variables).to include('JVM_LIB_FILE=$PWD/.test-java-home/lib/amd64/server/libjvm.so')
      expect(environment_variables).to include('TAKIPI_HOME=$PWD/.java-buildpack/takipi_agent')
    end

    it 'updates user environment variables' do
      component.release

      expect(environment_variables).to include('TAKIPI_SECRET_KEY=test-secret')
      expect(environment_variables).to include('TAKIPI_MASTER_HOST=test-host')
      expect(environment_variables).to include('TAKIPI_MASTER_PORT=test-port')
    end

    context 'configuration overrides' do

      let(:configuration) do
        { 'node_name_prefix' => 'test-name',
          'application_name' => 'test-name' }
      end

      it 'updates JAVA_OPTS' do
        component.release
        expect(java_opts).to include('-agentlib:TakipiAgent')
        expect(java_opts).to include('-Dtakipi.name=test-name')
      end

    end
  end

end
