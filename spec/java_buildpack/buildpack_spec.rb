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
require 'application_helper'
require 'logging_helper'
require 'java_buildpack/buildpack'

describe JavaBuildpack::Buildpack do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:stub_container1) { double('StubContainer1', detect: nil, component_name: 'StubContainer1') }

  let(:stub_container2) { double('StubContainer2', detect: nil, component_name: 'StubContainer2') }

  let(:stub_framework1) { double('StubFramework1', detect: nil) }

  let(:stub_framework2) { double('StubFramework2', detect: nil) }

  let(:stub_jre1) { double('StubJre1', detect: nil, component_name: 'StubJre1') }

  let(:stub_jre2) { double('StubJre2', detect: nil, component_name: 'StubJre2') }

  let(:buildpack) do
    buildpack = nil
    described_class.with_buildpack(app_dir, 'Error %s') { |b| buildpack = b }
    buildpack
  end

  before do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).and_call_original
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('components')
                                                      .and_return(
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

  it 'should raise an error if more than one container can run an application' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_container2).to receive(:detect).and_return('stub-container-2')

    expect { buildpack.detect }
    .to raise_error /Application can be run by more than one container: Mock, Mock/
  end

  it 'should raise an error if more than one JRE can run an application' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')
    allow(stub_jre2).to receive(:detect).and_return('stub-jre-2')

    expect { buildpack.detect }.to raise_error /Application can be run by more than one JRE: Mock, Mock/
  end

  it 'should return no detections if no container can run an application' do
    expect(buildpack.detect).to be_empty
  end

  context do

    before do
      allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('components')
                                                        .and_return(
                                                            'containers' => [],
                                                            'frameworks' => ['JavaBuildpack::Framework::JavaOpts'],
                                                            'jres'       => []
                                                        )
    end

    it 'should require files needed for components' do
      buildpack
    end
  end

  it 'should call compile on matched components' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_framework1).to receive(:detect).and_return('stub-framework-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')

    expect(stub_container1).to receive(:compile)
    expect(stub_container2).not_to receive(:compile)
    expect(stub_framework1).to receive(:compile)
    expect(stub_framework2).not_to receive(:compile)
    expect(stub_jre1).to receive(:compile)
    expect(stub_jre2).not_to receive(:compile)

    buildpack.compile
  end

  it 'should call release on matched components' do
    allow(stub_container1).to receive(:detect).and_return('stub-container-1')
    allow(stub_framework1).to receive(:detect).and_return('stub-framework-1')
    allow(stub_jre1).to receive(:detect).and_return('stub-jre-1')
    allow(stub_container1).to receive(:release).and_return('test-command')

    expect(stub_container1).to receive(:release)
    expect(stub_container2).not_to receive(:release)
    expect(stub_framework1).to receive(:release)
    expect(stub_framework2).not_to receive(:release)
    expect(stub_jre1).to receive(:release)
    expect(stub_jre2).not_to receive(:release)

    expect(buildpack.release)
    .to eq({ 'addons' => [], 'config_vars' => {}, 'default_process_types' => { 'web' => 'test-command' } }.to_yaml)
  end

  it 'should load configuration file matching JRE class name' do
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_jre1')
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_jre2')
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_framework1')
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_framework2')
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_container1')
    expect(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('stub_container2')

    buildpack.detect
  end

  it 'logs information about the git repository of a buildpack',
     log_level: 'DEBUG' do

    buildpack.detect

    expect(stderr.string).to match /git remotes/
    expect(stderr.string).to match /git HEAD commit/
  end

  it 'prints output during compile showing the git repository of a buildpack' do
    expect { buildpack.compile }.to raise_error # ok since fixture has no application

    expect(stdout.string).to match /Java Buildpack source: .*#.*/
  end

  it 'realises when buildpack is not stored in a git repository',
     log_level: 'DEBUG' do

    Dir.mktmpdir do |tmp_dir|
      stub_const(described_class.to_s + '::GIT_DIR', Pathname.new(tmp_dir))

      with_buildpack { |buildpack| buildpack.detect }

      expect(stderr.string).to match /Java Buildpack source: system/
    end
  end

  it 'prints output during compile showing that buildpack is not stored in a git repository' do

    Dir.mktmpdir do |tmp_dir|
      stub_const(described_class.to_s + '::GIT_DIR', Pathname.new(tmp_dir))

      with_buildpack { |buildpack| expect { buildpack.compile } .to raise_error }  # error ok since fixture has no application

      expect(stdout.string).to match /Java Buildpack source: system/
    end
  end

  it 'handles exceptions correctly' do
    expect { with_buildpack { |buildpack| fail 'an exception' } }.to raise_error SystemExit
    expect(stderr.string).to match /an exception/
  end

  def with_buildpack(&block)
    described_class.with_buildpack(app_dir, 'Error %s') do |buildpack|
      block.call buildpack
    end
  end

end

module Test
  class StubContainer1
  end

  class StubContainer2
  end

  class StubJre1
  end

  class StubJre2
  end

  class StubFramework1
  end

  class StubFramework2
  end
end
