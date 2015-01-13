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
require 'java_buildpack/jre/oracle_jre'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'

describe JavaBuildpack::Jre::OracleJRE do
  include_context 'component_helper'

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(opt-1 opt-2)) }

  let(:configuration) do
    { 'version'           => { 'detect_compile' => 'disabled',
                               8                => '1.8.0_+',
                               7                => '1.7.0_+',
                               6                => '1.6.0_+' },
      'memory_sizes'      => { 'metaspace' => '64m..',
                               'permgen'   => '64m..' },
      'memory_heuristics' => { 'heap'      => '75',
                               'metaspace' => '10',
                               'permgen'   => '10',
                               'stack'     => '5',
                               'native'    => '10' } }
  end

  before do
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new).and_return(memory_heuristic)
  end

  it 'detects with id of oracle-jre-<version>' do
    expect(component.detect).to eq("oracle-jre=#{version}")
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

  it 'adds memory options to java_opts' do
    component.detect
    component.release

    expect(java_opts).to include('opt-1')
    expect(java_opts).to include('opt-2')
  end

  it 'adds OnOutOfMemoryError to java_opts' do
    component.detect
    component.release

    expect(java_opts).to include('-XX:OnOutOfMemoryError=$PWD/.java-buildpack/oracle_jre/bin/killjava.sh')
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

  context do

    let(:configuration) { super().merge 'version' => { 'detect_compile' => 'enabled' } }

    let(:component) { StubOracleJRE.new context }

    context do

      let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(java6)) }

      it 'adds memory options to java_opts for a java 6 app' do
        expect(component.memory(6, JavaBuildpack::Util::TokenizedVersion.new('1.6.0'))).to include('java6')
      end

    end

    context do

      let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(java7)) }

      it 'adds memory options to java_opts for a java 7 app' do
        expect(component.memory(7, JavaBuildpack::Util::TokenizedVersion.new('1.7.0'))).to include('java7')
      end

    end

    context do

      let(:memory_heuristic) { double('MemoryHeuristic', resolve: %w(java8)) }

      it 'adds memory options to java_opts for a java 8 app' do
        expect(component.memory(8, JavaBuildpack::Util::TokenizedVersion.new('1.8.0'))).to include('java8')
      end

    end

    it 'detects the correct version for a java 6 app',
       cache_fixture: 'stub-java.tar.gz',
       app_fixture:   'jre_java6_application' do

      expect(component.compiled_version Pathname.new('spec/fixtures/jre_java6_application')).to eq(6)
    end

    it 'detects the correct version for a java 7 app',
       cache_fixture: 'stub-java.tar.gz',
       app_fixture:   'jre_java7_application' do

      expect(component.compiled_version Pathname.new('spec/fixtures/jre_java7_application')).to eq(7)
    end

    it 'detects the correct version for a java 8 app',
       cache_fixture: 'stub-java.tar.gz',
       app_fixture:   'jre_java8_application' do

      expect(component.compiled_version Pathname.new('spec/fixtures/jre_java8_application')).to eq(8)
    end

    class StubOracleJRE < JavaBuildpack::Jre::OracleJRE
      public :compiled_version, :memory
    end

  end

end
