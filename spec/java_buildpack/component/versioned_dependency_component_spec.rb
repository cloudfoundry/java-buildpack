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
require 'java_buildpack/component/versioned_dependency_component'

describe JavaBuildpack::Component::VersionedDependencyComponent do
  include_context 'component_helper'

  let(:component) { StubVersionedDependencyComponent.new context }

  it 'fails if methods are unimplemented' do
    expect { component.compile }.to raise_error
    expect { component.release }.to raise_error
    expect { component.supports? }.to raise_error
  end

  context do
    before do
      allow_any_instance_of(StubVersionedDependencyComponent).to receive(:supports?).and_return(false)
    end

    it 'returns nil from detect if not supported' do
      expect(component.detect).to be_nil
    end
  end

  context do

    before do
      allow_any_instance_of(StubVersionedDependencyComponent).to receive(:supports?).and_return(true)
    end

    it 'returns name and version string from detect if supported' do
      expect(component.detect).to eq("stub-versioned-dependency-component=#{version}")
    end

    it 'downloads jar file and put it in the sandbox',
       cache_fixture: 'stub-download.jar' do

      component.download_jar
      expect(droplet.sandbox + "versioned_dependency_component-#{version}.jar").to exist
    end

    it 'downloads and expand TAR file in the sandbox',
       cache_fixture: 'stub-download.tar.gz' do

      component.download_tar
      expect(droplet.sandbox + 'test-file').to exist
    end

    it 'downloads and expand ZIP file in the sandbox',
       cache_fixture: 'stub-download.zip' do

      component.download_zip(false)
      expect(droplet.sandbox + 'test-file').to exist
    end

    it 'downloads and expand ZIP file, stripping the top level directory in the sandbox',
       cache_fixture: 'stub-download-with-top-level.zip' do

      component.download_zip
      expect(droplet.sandbox + 'test-file').to exist
    end
  end

end

class StubVersionedDependencyComponent < JavaBuildpack::Component::VersionedDependencyComponent

  public :supports?, :download_jar, :download_tar, :download_zip

end
