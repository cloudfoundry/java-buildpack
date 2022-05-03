# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2021 the original author or authors.
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
require 'java_buildpack/framework/datadog_javaagent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::DatadogJavaagent do
  include_context 'with component help'

  let(:configuration) do
    { 'default_application_version' => nil,
      'default_application_name' => nil }
  end

  describe '#detect' do
    subject(:detect) { component.detect }

    it 'does not detect without an api key' do
      expect(detect).to be_nil
    end

    context 'when api key is empty' do
      let(:environment) { { 'DD_API_KEY' => '' } }

      it { is_expected.to be_nil }
    end

    context 'when apm is disabled' do
      let(:environment) { { 'DD_API_KEY' => 'foo', 'DD_APM_ENABLED' => 'false' } }

      it { is_expected.to be_nil }
    end

    context 'when apm is enabled with no api key' do
      let(:environment) { { 'DD_APM_ENABLED' => 'true' } }

      it { is_expected.to be_nil }
    end

    context 'when apm key is provided' do
      let(:environment) { { 'DD_API_KEY' => 'foo' } }

      it { is_expected.to eq("datadog-javaagent=#{version}") }
    end
  end

  context 'when apm key is provided' do
    let(:environment) do
      super().update({ 'DD_API_KEY' => 'foo' })
    end

    context 'when datadog buildpack is present' do
      before do
        FileUtils.mkdir_p File.join(context[:droplet].root, '.datadog')
      end

      after do
        FileUtils.rmdir File.join(context[:droplet].root, '.datadog')
      end

      it 'compile downloads datadog-javaagent JAR', cache_fixture: 'stub-datadog-javaagent.jar' do
        component.compile
        expect(sandbox + "datadog_javaagent-#{version}.jar").to exist
      end

      it 'makes a jar with fake class files', cache_fixture: 'stub-datadog-javaagent.jar' do
        component.compile
        expect(sandbox + "datadog_javaagent-#{version}.jar").to exist
        expect(sandbox + 'datadog_fakeclasses.jar').to exist
        expect(sandbox + 'datadog_fakeclasses').not_to exist

        cnt = `unzip -l #{sandbox}/datadog_fakeclasses.jar | grep '\\(\\.class\\)$' | wc -l`.to_i
        expect(cnt).to equal(34)
      end

      it 'release updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include(
          "-javaagent:$PWD/.java-buildpack/datadog_javaagent/datadog_javaagent-#{version}.jar"
        )
        expect(java_opts).to include('-Ddd.service=\"test-application-name\"')
        expect(java_opts).to include('-Ddd.version=test-application-version')
      end
    end

    context 'when datadog buildpack 4.22.0 (or older) is present' do
      before do
        FileUtils.mkdir_p File.join(context[:droplet].root, 'datadog')
      end

      after do
        FileUtils.rmdir File.join(context[:droplet].root, 'datadog')
      end

      it 'compile downloads datadog-javaagent JAR', cache_fixture: 'stub-datadog-javaagent.jar' do
        component.compile
        expect(sandbox + "datadog_javaagent-#{version}.jar").to exist
      end

      it 'makes a jar with fake class files', cache_fixture: 'stub-datadog-javaagent.jar' do
        component.compile
        expect(sandbox + "datadog_javaagent-#{version}.jar").to exist
        expect(sandbox + 'datadog_fakeclasses.jar').to exist
        expect(sandbox + 'datadog_fakeclasses').not_to exist

        cnt = `unzip -l #{sandbox}/datadog_fakeclasses.jar | grep '\\(\\.class\\)$' | wc -l`.to_i
        expect(cnt).to equal(34)
      end

      it 'release updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include(
          "-javaagent:$PWD/.java-buildpack/datadog_javaagent/datadog_javaagent-#{version}.jar"
        )
        expect(java_opts).to include('-Ddd.service=\"test-application-name\"')
        expect(java_opts).to include('-Ddd.version=test-application-version')
      end
    end

    context 'when datadog buildpack is not present' do
      it 'compile downloads datadog-javaagent JAR', cache_fixture: 'stub-datadog-javaagent.jar' do
        component.compile
        expect(sandbox + "datadog_javaagent-#{version}.jar").not_to exist
      end

      it 'release updates JAVA_OPTS' do
        component.release

        expect(java_opts).not_to include(
          "-javaagent:$PWD/.java-buildpack/datadog_javaagent/datadog_javaagent-#{version}.jar"
        )
        expect(java_opts).not_to include('-Ddd.service=\"test-application-name\"')
        expect(java_opts).not_to include('-Ddd.version=test-application-version')
      end
    end
  end

  context 'when dd_version environment variable is provided' do
    let(:environment) do
      super().update({ 'DD_VERSION' => 'env-variable-version' })
    end

    before do
      FileUtils.mkdir_p File.join(context[:droplet].root, '.datadog')
    end

    after do
      FileUtils.rmdir File.join(context[:droplet].root, '.datadog')
    end

    it 'release updates JAVA_OPTS with env variable version' do
      component.release

      expect(java_opts).to include('-Ddd.version=env-variable-version')
    end
  end
end
