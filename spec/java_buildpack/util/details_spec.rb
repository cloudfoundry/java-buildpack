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
require 'java_buildpack/util/details'

module JavaBuildpack::Util

  describe Details do

    RESOLVED_VERSION = 'resolved-version'

    RESOLVED_URI = 'resolved-uri'

    before do
      RepositoryIndex.stub(:new).and_return({ RESOLVED_VERSION => RESOLVED_URI })
    end

    it 'raises an error if no repository root is specified' do
      expect { Details.new({}) }.to raise_error
    end

    it 'resolves a system.properties version if specified' do
      VersionResolver.stub(:resolve).with('test-java-runtime-version', [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = Details.new(
        'repository_root' => 'test-repository-root',
        'java.runtime.version' => 'test-java-runtime-version',
        'version' => 'test-version'
      )

      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

    it 'resolves a configuration version if specified' do
      VersionResolver.stub(:resolve).with('test-version', [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = Details.new(
        'repository_root' => 'test-repository-root',
        'version' => 'test-version'
      )

      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

    it 'resolves nil if no version is specified' do
      VersionResolver.stub(:resolve).with(nil, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = Details.new(
        'repository_root' => 'test-repository-root'
      )

      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)

    end

  end

end
