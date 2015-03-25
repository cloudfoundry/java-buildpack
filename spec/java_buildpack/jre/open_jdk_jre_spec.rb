# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/open_jdk_jre'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

describe JavaBuildpack::Jre::OpenJdkJRE do
  include_context 'component_helper'

  let(:version_8) { VERSION_8 = JavaBuildpack::Util::TokenizedVersion.new('1.8.0_+') }

  let(:version_7) { VERSION_7 = JavaBuildpack::Util::TokenizedVersion.new('1.7.0_+') }

  let(:configuration) do
    { 'memory_sizes'      => { 'metaspace' => '64m..',
                               'permgen'   => '64m..' },
      'memory_heuristics' => { 'heap'      => '75',
                               'metaspace' => '10',
                               'permgen'   => '10',
                               'stack'     => '5',
                               'native'    => '10' } }
  end

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:memory_heuristic_7) { double('MemoryHeuristic', resolve: %w(opt-7-1 opt-7-2)) }

  let(:memory_heuristic_8) { double('MemoryHeuristic', resolve: %w(opt-8-1 opt-8-2)) }

  before do
    allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item).and_return([version_8, 'test-uri'])
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new).with({ 'permgen' => '64m..' },
                                                                                    anything, anything, anything)
                                                                   .and_return(memory_heuristic_7)
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new).with({ 'metaspace' => '64m..' },
                                                                                    anything, anything, anything)
                                                                   .and_return(memory_heuristic_8)
  end

  it 'detects with id of openjdk_jre-<version>' do
    expect(component.detect).to eq("open-jdk-jre=#{version_8}")
  end

  it 'extracts Java from a GZipped TAR',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.compile

    expect(sandbox + 'bin/java').to exist
  end

  it 'adds the JAVA_HOME to java_home' do
    component

    expect(java_home.root).to eq(sandbox)
  end

  it 'adds OnOutOfMemoryError to java_opts' do
    component.detect
    component.release

    expect(java_opts).to include('-XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk_jre/bin/killjava.sh')
  end

  it 'places the killjava script (with appropriately substituted content) in the diagnostics directory',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.compile

    expect(sandbox + 'bin/killjava.sh').to exist
  end

  it 'adds java.io.tmpdir to java_opts' do
    component.detect
    component.release

    expect(java_opts).to include('-Djava.io.tmpdir=$TMPDIR')
  end

  it 'removes memory options for a java 8 app',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.release

    expect(java_opts).to include('opt-8-1')
    expect(java_opts).to include('opt-8-2')
  end

  context do

    before do
      allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item).and_return([version_7, 'test-uri'])
    end

    it 'removes memory options for a java 7 app',
       cache_fixture: 'stub-java.tar.gz' do

      component.detect
      component.release

      expect(java_opts).to include('opt-7-1')
      expect(java_opts).to include('opt-7-2')
    end

  end

end
