# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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
require 'java_buildpack/container/tomcat_details'

module JavaBuildpack::Container

  describe TomcatDetails do

    VERSION_KEY = 'version'
    REPOSITORY_ROOT_KEY = 'repository_root'
    TEST_VERSION = '7.0.40'
    TEST_MALFORMED_VERSION_WITH_QUALIFIER = '7.0.40_1'
    TEST_MALFORMED_VERSION_WITHOUT_QUALIFIER = '7.'
    RESOLVED_URI = 'resolved-uri'
    RESOLVED_ROOT = 'resolved-root'
    RESOLVED_VERSION = 'resolved-version'
    DEFAULT_VERSION = '+'

    it 'returns the resolved id, version, and uri from a configuration' do
      TomcatDetails.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(TEST_VERSION, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = TomcatDetails.new({VERSION_KEY => TEST_VERSION, REPOSITORY_ROOT_KEY => RESOLVED_ROOT})

      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

    it 'uses the default version if no version is configured' do
      TomcatDetails.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(DEFAULT_VERSION, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = TomcatDetails.new({REPOSITORY_ROOT_KEY => RESOLVED_ROOT})

      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

    it 'fails if the repository root is not configured' do
      expect { TomcatDetails.new({VERSION_KEY => TEST_VERSION}) }.to raise_error(/repository\ root/)
    end

    it 'fails if the version is malformed because it has a qualifier' do
      TomcatDetails.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(TEST_MALFORMED_VERSION_WITH_QUALIFIER, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      expect { TomcatDetails.new({VERSION_KEY => TEST_MALFORMED_VERSION_WITH_QUALIFIER, REPOSITORY_ROOT_KEY => RESOLVED_ROOT}) }.to raise_error(/Malformed\ Tomcat\ version/)
      end

    it 'fails with a Tomcat-specific message if the version is otherwise malformed' do
      TomcatDetails.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(TEST_MALFORMED_VERSION_WITHOUT_QUALIFIER, [RESOLVED_VERSION]).and_raise('malformed')

      expect { TomcatDetails.new({VERSION_KEY => TEST_MALFORMED_VERSION_WITHOUT_QUALIFIER, REPOSITORY_ROOT_KEY => RESOLVED_ROOT}) }.to raise_error(/Tomcat\ container\ error/)
    end

  end

end
