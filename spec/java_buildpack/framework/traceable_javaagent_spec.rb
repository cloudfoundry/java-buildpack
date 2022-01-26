# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2022 the original author or authors.
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
require 'java_buildpack/framework/traceable_javaagent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::TraceableJavaagent do
  include_context 'with component help'

  let(:configuration) do
    { 'default_application_version' => nil,
      'default_application_name' => nil }
  end

  describe '#detect' do
    subject(:detect) { component.detect }

    it 'does not detect without an endpoint ' do
      expect(detect).to be nil
    end

    context 'when endpoint is empty' do
      let(:environment) { { 'HT_REPORTING_ENDPOINT' => '' } }

      it { is_expected.to be nil }
    end

    context 'when endpoint is provided' do
      let(:environment) do
        {
          'HT_REPORTING_ENDPOINT' => 'http://localhost:4317',
          'TA_OPA_ENDPOINT' => 'http://localhost:8181'
        }
      end

      it { is_expected.to eq("traceable-javaagent=#{version}") }
    end
  end

  context 'when endpoint is provided' do
    let(:environment) do
      super().update({
                       'HT_REPORTING_ENDPOINT' => 'http://localhost:4317',
                       'TA_OPA_ENDPOINT' => 'http://localhost:8181'
                     })
    end

    it 'compile downloads traceable-javaagent JAR', cache_fixture: 'stub-traceable-javaagent.jar' do
      component.compile
      expect(sandbox + "traceable_javaagent-#{version}.jar").to exist
    end

    it 'release updates JAVA_OPTS' do
      component.release

      expect(java_opts).to include(
        "-javaagent:$PWD/.java-buildpack/traceable_javaagent/traceable_javaagent-#{version}.jar"
      )
      expect(java_opts).to include('-Dht.service.name=\"test-application-name\"')
    end
  end
end
