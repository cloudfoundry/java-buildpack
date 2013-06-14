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
require 'java_buildpack/jre/details'

module JavaBuildpack::Jre

  describe Details do

    CANDIDATE_VENDOR = 'candidate-vendor'

    CANDIDATE_VERSION = 'candidate-version'

    DEFAULT_VERSION = 'default-version'

    RESOLVED_ROOT = 'resolved-root'

    RESOLVED_VENDOR = 'resolved-vendor'

    RESOLVED_VERSION = 'resolved-version'

    RESOLVED_URI = 'resolved-uri'

    it 'returns the resolved id, vendor, version, and uri from uri-only vendor details' do
      YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => RESOLVED_ROOT)
      VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)
      JavaBuildpack::Util::RepositoryIndex.stub(:new).and_return({ 'resolved-version' => 'resolved-uri' })
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(CANDIDATE_VERSION, nil, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = Details.new({ 'java.runtime.vendor' => CANDIDATE_VENDOR, 'java.runtime.version' => CANDIDATE_VERSION})

      expect(details.vendor).to eq(RESOLVED_VENDOR)
      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

  it 'returns the resolved id, vendor, version, and uri from extended vendor details' do
      YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => {'default_version' => DEFAULT_VERSION, 'repository_root' => RESOLVED_ROOT})
      VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)
      JavaBuildpack::Util::RepositoryIndex.stub(:new).and_return({ 'resolved-version' => 'resolved-uri' })
      JavaBuildpack::Util::VersionResolver.stub(:resolve).with(CANDIDATE_VERSION, DEFAULT_VERSION, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

      details = Details.new({ 'java.runtime.vendor' => CANDIDATE_VENDOR, 'java.runtime.version' => CANDIDATE_VERSION})

      expect(details.vendor).to eq(RESOLVED_VENDOR)
      expect(details.version).to eq(RESOLVED_VERSION)
      expect(details.uri).to eq(RESOLVED_URI)
    end

    it 'raises an error if the vendor details are not of a valid structure' do
      YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => {'uri' => RESOLVED_ROOT})
      VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)

      expect { Details.new({ 'java.runtime.vendor' => CANDIDATE_VENDOR, 'java.runtime.version' => CANDIDATE_VERSION}) }.to raise_error
    end

  end

end
