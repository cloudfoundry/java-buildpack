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
require 'component_helper'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/open_jdk'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

describe JavaBuildpack::Jre::OpenJDK do
  include_context 'component_helper'

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(opt-1 opt-2)) }

  before do
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new).and_return(memory_heuristic)
  end

  it 'should detect with id of openjdk-<version>' do
    expect(component.detect).to eq("open-jdk=#{version}")
  end

  it 'should extract Java from a GZipped TAR',
     cache_fixture: 'stub-java.tar.gz' do

    component.compile

    expect(sandbox + 'bin/java').to exist
  end

  it 'adds the JAVA_HOME to java_home' do
    component

    expect(java_home.root).to eq(sandbox)
  end

  it 'should add memory options to java_opts' do
    component.release

    expect(java_opts).to include('opt-1')
    expect(java_opts).to include('opt-2')
  end

  it 'adds OnOutOfMemoryError to java_opts' do
    component.release

    expect(java_opts).to include('-XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk/bin/killjava.sh')
  end

  it 'places the killjava script (with appropriately substituted content) in the diagnostics directory',
     cache_fixture: 'stub-java.tar.gz' do

    component.compile

    expect(sandbox + 'bin/killjava.sh').to exist
  end

  it 'adds java.io.tmpdir to java_opts' do
    component.release

    expect(java_opts).to include('-Djava.io.tmpdir=$TMPDIR')
  end

end
