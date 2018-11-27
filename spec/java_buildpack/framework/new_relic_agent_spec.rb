# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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
require 'internet_availability_helper'
require 'java_buildpack/framework/new_relic_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::NewRelicAgent do
  include_context 'with component help'

  it 'does not detect without newrelic-n/a service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/newrelic/, %w[licenseKey license_key]).and_return(true)
    end

    it 'detects with newrelic-n/a service' do
      expect(component.detect).to eq("new-relic-agent=#{version}")
    end

    it 'downloads New Relic agent JAR',
       cache_fixture: 'stub-new-relic-agent.jar' do

      component.compile

      expect(sandbox + "new_relic_agent-#{version}.jar").to exist
    end

    it 'copies resources',
       cache_fixture: 'stub-new-relic-agent.jar' do

      component.compile

      expect(sandbox + 'newrelic.yml').to exist
    end

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'licenseKey' => 'test-license-key' })
      allow(java_home).to receive(:java_8_or_later?).and_return(JavaBuildpack::Util::TokenizedVersion.new('1.7.0_u10'))

      component.release

      expect(java_opts).to include("-javaagent:$PWD/.java-buildpack/new_relic_agent/new_relic_agent-#{version}.jar")
      expect(java_opts).to include('-Dnewrelic.home=$PWD/.java-buildpack/new_relic_agent')
      expect(java_opts).to include('-Dnewrelic.config.license_key=test-license-key')
      expect(java_opts).to include('-Dnewrelic.config.app_name=test-application-name')
      expect(java_opts).to include('-Dnewrelic.config.log_file_name=STDOUT')
    end

    it 'updates JAVA_OPTS with additional options' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'licenseKey' => 'test-license-key',
                                                                              'license_key' => 'different-license-key',
                                                                              'app_name' => 'different-name',
                                                                              'foo' => 'bar' })
      allow(java_home).to receive(:java_8_or_later?).and_return(JavaBuildpack::Util::TokenizedVersion.new('1.7.0_u10'))

      component.release

      expect(java_opts).to include('-Dnewrelic.config.license_key=different-license-key')
      expect(java_opts).to include('-Dnewrelic.config.app_name=different-name')
      expect(java_opts).to include('-Dnewrelic.config.foo=bar')
    end

    it 'updates JAVA_OPTS on Java 8' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'licenseKey' => 'test-license-key' })
      allow(java_home).to receive(:java_8_or_later?).and_return(JavaBuildpack::Util::TokenizedVersion.new('1.8.0_u10'))

      component.release

      expect(java_opts).to include('-Dnewrelic.enable.java.8=true')
    end

    context 'when extensions are configured' do

      extensions_version = '1.2.3'
      extensions_repo_root = 'test-extensions-repository-root'
      extensions_uri = 'test-extensions-uri'
      stubbed_extensions_configuration = { 'repository_root' => extensions_repo_root,
                                           'version' => extensions_version }

      before do |example|
        context[:configuration]['extensions'] = example.metadata[:configuration]

        # Extra stubbing for the extensions tarfile fixture
        extensions_tokenized_version = JavaBuildpack::Util::TokenizedVersion.new(extensions_version)
        allow(JavaBuildpack::Repository::ConfiguredItem)
          .to receive(:find_item).with(anything, stubbed_extensions_configuration) do |&block|
          block&.call(extensions_tokenized_version)
        end.and_return([extensions_tokenized_version, extensions_uri])

        allow(application_cache).to receive(:get)
          .with(extensions_uri)
          .and_yield(Pathname.new('spec/fixtures/stub-new-relic-extensions.tar').open, false)
      end

      it 'downloads extensions TAR',
         cache_fixture: 'stub-new-relic-agent.jar',
         configuration: stubbed_extensions_configuration do

        component.compile

        expect(stdout.string)
          .to match(/Downloading New Relic Agent Extensions #{extensions_version} from #{extensions_uri}/)
        expect(sandbox + 'extensions/extension-example.xml').to exist
      end

      it 'does guarantee that internet access is available when downloading',
         cache_fixture: 'stub-new-relic-agent.jar',
         configuration: stubbed_extensions_configuration do

        expect_any_instance_of(JavaBuildpack::Util::Cache::InternetAvailability)
          .to receive(:available).with(true, 'The New Relic Agent Extensions download location is always accessible')

        component.compile
      end

      {
        'missing extensions configuration' => nil,
        'missing extensions repository' => { 'version' => extensions_version },
        'blank extensions repository' => { 'repository_root' => '', 'version' => extensions_version }
      }.each do |non_provided_repository_desc, config|
        it "ignores #{non_provided_repository_desc}",
           cache_fixture: 'stub-new-relic-agent.jar',
           configuration: config do

          component.compile

          expect(stdout.string).not_to match(/New Relic Agent Extensions/)
          expect(sandbox + 'extensions').not_to exist
        end
      end

    end

  end

end
