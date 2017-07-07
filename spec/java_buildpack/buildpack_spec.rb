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
require 'application_helper'
require 'logging_helper'
require 'java_buildpack/buildpack'
require 'java_buildpack/component/base_component'

describe JavaBuildpack::Buildpack do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:stub_container1) { instance_double('StubContainer1', detect: nil, component_name: 'StubContainer1') }

  let(:stub_container2) do
    instance_double('StubContainer2', detect: nil, compile: nil, release: nil, component_name: 'StubContainer2')
  end

  let(:stub_framework1) { instance_double('StubFramework1', detect: nil) }

  let(:stub_framework2) { instance_double('StubFramework2', detect: nil, compile: nil, release: nil) }

  let(:stub_jre1) { instance_double('StubJre1', detect: nil, component_name: 'StubJre1') }

  let(:stub_jre2) { instance_double('StubJre2', detect: nil, compile: nil, release: nil, component_name: 'StubJre2') }

  let(:buildpack) do
    buildpack = nil
    described_class.with_buildpack(app_dir, 'Error %s') { |b| buildpack = b }
    buildpack
  end

  before do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).and_call_original
    allow(JavaBuildpack::Util::ConfigurationUtils)
      .to receive(:load).with('components').and_return(
        'containers' => ['Test::StubContainer1', 'Test::StubContainer2'],
        'frameworks' => ['Test::StubFramework1', 'Test::StubFramework2'],
        'jres'       => ['Test::StubJre1', 'Test::StubJre2']
      )

    allow(Test::StubContainer1).to receive(:new).and_return(stub_container1)
    allow(Test::StubContainer2).to receive(:new).and_return(stub_container2)

    allow(Test::StubFramework1).to receive(:new).and_return(stub_framework1)
    allow(Test::StubFramework2).to receive(:new).and_return(stub_framework2)

    allow(Test::StubJre1).to receive(:new).and_return(stub_jre1)
    allow(Test::StubJre2).to receive(:new).and_return(stub_jre2)
  end

  it 'raises an error if more than one container can run an application' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_container2).to receive(:detect).and_return('stub-container-2')

    expect { buildpack.detect }
      .to raise_error(/Application can be run by more than one container/)
  end

  it 'raises an error if more than one JRE can run an application' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')
    allow(stub_jre2).to receive(:detect).and_return('stub-jre-2')

    expect { buildpack.detect }.to raise_error(/Application can be run by more than one JRE/)
  end

  it 'returns no detections if no container can run an application' do
    expect(buildpack.detect).to be_empty
  end

  context do

    before do
      allow(JavaBuildpack::Util::ConfigurationUtils)
        .to receive(:load).with('components')
                          .and_return(
                            'containers' => [],
                            'frameworks' => ['JavaBuildpack::Framework::JavaOpts'],
                            'jres'       => []
                          )
    end

    it 'requires files needed for components' do
      buildpack
    end
  end

  it 'calls compile on matched components' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_framework1).to receive(:detect).and_return('stub-framework-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')

    allow(stub_container1).to receive(:compile)
    expect(stub_container2).not_to have_received(:compile)
    allow(stub_framework1).to receive(:compile)
    expect(stub_framework2).not_to have_received(:compile)
    allow(stub_jre1).to receive(:compile)
    expect(stub_jre2).not_to have_received(:compile)

    buildpack.compile
  end

  it 'calls release on matched components' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_framework1).to receive(:detect).and_return('stub-framework-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')

    allow(stub_container1).to receive(:release).and_return('test-command')
    expect(stub_container2).not_to have_received(:release)
    allow(stub_framework1).to receive(:release)
    expect(stub_framework2).not_to have_received(:release)
    allow(stub_jre1).to receive(:release)
    expect(stub_jre2).not_to have_received(:release)

    expect(buildpack.release)
      .to eq({ 'addons'                => [],
               'config_vars'           => {},
               'default_process_types' => { 'web'  => 'JAVA_OPTS="" && test-command',
                                            'task' => 'JAVA_OPTS="" && test-command' } }.to_yaml)
  end

  it 'loads configuration file matching JRE class name' do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_jre1')
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_jre2')
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_framework1')
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_framework2')
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_container1')
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_container2')

    buildpack.detect
  end

  it 'handles exceptions' do
    expect { with_buildpack { |_buildpack| raise 'an exception' } }.to raise_error SystemExit
    expect(stderr.string).to match(/an exception/)
  end

  def with_buildpack(&_)
    described_class.with_buildpack(app_dir, 'Error %s') { |buildpack| yield buildpack }
  end

end

module Test
  class StubContainer1 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end

  class StubContainer2 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end

  class StubJre1 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end

  class StubJre2 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end

  class StubFramework1 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end

  class StubFramework2 < JavaBuildpack::Component::BaseComponent
    attr_reader :component_name
  end
end
