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
require 'java_buildpack/framework/jacoco_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::JacocoAgent do
  include_context 'with component help'

  it 'does not detect without jacoco service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/jacoco/, 'address').and_return(true)
    end

    it 'detects with jacoco service' do
      expect(component.detect).to eq("jacoco-agent=#{version}")
    end

    it 'downloads JaCoco agent JAR',
       cache_fixture: 'stub-jacoco-agent.jar' do

      component.compile

      expect(sandbox + 'jacocoagent.jar').to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'address' => 'test-address' })

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/jacoco_agent/jacocoagent.jar=' \
                                   'address=test-address,output=tcpclient,sessionid=$CF_INSTANCE_GUID')
    end

    it 'updates JAVA_OPTS with additional options' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'address' => 'test-address',
                                                                              'output' => 'test-output',
                                                                              'excludes' => 'test-excludes',
                                                                              'includes' => 'test-includes',
                                                                              'port' => 6300 })

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/jacoco_agent/jacocoagent.jar=' \
                                   'address=test-address,output=test-output,sessionid=$CF_INSTANCE_GUID,' \
                                   'excludes=test-excludes,includes=test-includes,port=6300')
    end

  end

end
