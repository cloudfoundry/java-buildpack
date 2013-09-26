# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/repository/configured_item'

module JavaBuildpack::Repository

  describe ConfiguredItem do

    RESOLVED_VERSION = 'resolved-version'
    RESOLVED_URI = 'resolved-uri'
    VERSION_KEY = 'version'
    REPOSITORY_ROOT_KEY = 'repository_root'
    RESOLVED_ROOT = 'resolved-root'

    before do
      JavaBuildpack::Repository::RepositoryIndex.stub(:new).and_return(double('repository index', find_item: [RESOLVED_VERSION, RESOLVED_URI]))
    end

    it 'raises an error if no repository root is specified' do
      expect { ConfiguredItem.find_item('Test', {}) }.to raise_error
    end

    it 'resolves a system.properties version if specified' do
      details = ConfiguredItem.find_item('Test',
                                         'repository_root' => 'test-repository-root',
                                         'java.runtime.version' => 'test-java-runtime-version',
                                         'version' => '1.7.0'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

    it 'resolves a configuration version if specified' do
      details = ConfiguredItem.find_item('Test',
                                         'repository_root' => 'test-repository-root',
                                         'version' => '1.7.0'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

    it 'drives the version validator block if supplied' do
      ConfiguredItem.find_item('Test',
                               'repository_root' => 'test-repository-root',
                               'version' => '1.7.0'
      ) do |version|
        expect(version).to eq(JavaBuildpack::Util::TokenizedVersion.new('1.7.0'))
      end
    end

    it 'resolves nil if no version is specified' do
      details = ConfiguredItem.find_item('Test',
                                         'repository_root' => 'test-repository-root'
      )

      expect(details[0]).to eq(RESOLVED_VERSION)
      expect(details[1]).to eq(RESOLVED_URI)
    end

  end

end
