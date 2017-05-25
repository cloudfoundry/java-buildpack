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
require 'java_buildpack/component/base_component'

describe JavaBuildpack::Component::BaseComponent do
  include_context 'component_helper'

  let(:component) { StubBaseComponent.new context }

  it 'assigns application to an instance variable' do
    expect(component.application).to equal(application)
  end

  it 'assigns component name to an instance variable' do
    expect(component.component_name).to eq('Stub Base Component')
  end

  it 'assigns configuration to an instance variable' do
    expect(component.configuration).to equal(configuration)
  end

  it 'assigns droplet to an instance variable' do
    expect(component.droplet).to equal(droplet)
  end

  it 'fails if methods are unimplemented' do
    expect { component.detect }.to raise_error
    expect { component.compile }.to raise_error
    expect { component.release }.to raise_error
  end

  it 'downloads file and yield it',
     cache_fixture: 'stub-download.jar' do

    component.download(version, uri) { |file| expect(file.path).to eq('spec/fixtures/stub-download.jar') }
    expect(stdout.string).to match(/Downloading Stub Base Component #{version} from #{uri}/)
  end

  it 'downloads jar file and put it in the sandbox',
     cache_fixture: 'stub-download.jar' do

    component.download_jar(version, uri, 'test.jar')
    expect(droplet.sandbox + 'test.jar').to exist
  end

  it 'downloads and expand TAR file in the sandbox',
     cache_fixture: 'stub-download.tar.gz' do

    component.download_tar(version, uri)
    expect(droplet.sandbox + 'test-file').to exist
  end

  it 'downloads and expand ZIP file in the sandbox',
     cache_fixture: 'stub-download.zip' do

    component.download_zip(version, uri, false)
    expect(droplet.sandbox + 'test-file').to exist
  end

  it 'downloads and expand ZIP file, stripping the top level directory in the sandbox',
     cache_fixture: 'stub-download-with-top-level.zip' do

    component.download_zip(version, uri)
    expect(droplet.sandbox + 'test-file').to exist
  end

  it 'prints timing information' do
    expect { |b| component.with_timing('test-caption', &b) }.to yield_control

    expect(stdout.string).to match(/     test-caption \([\d]\.[\d]s\)/)
  end

end

class StubBaseComponent < JavaBuildpack::Component::BaseComponent

  attr_reader :application, :component_name, :configuration, :droplet

  public :download, :download_jar, :download_tar, :download_zip, :with_timing

end
