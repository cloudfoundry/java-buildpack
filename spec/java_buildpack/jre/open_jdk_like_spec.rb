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
require 'fileutils'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/open_jdk_like'
require 'java_buildpack/jre/open_jdk_like_jre'
require 'java_buildpack/jre/open_jdk_like_memory_calculator'

describe JavaBuildpack::Jre::OpenJDKLike do
  include_context 'component_helper'

  let(:component) { StubOpenJDKLike.new context }

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:version_7) { VERSION_7 = JavaBuildpack::Util::TokenizedVersion.new('1.7.0_+') }

  let(:configuration) do
    { 'jre'               => jre_configuration,
      'memory_calculator' => memory_calculator_configuration }
  end

  let(:jre_configuration) { instance_double('jre_configuration') }

  let(:memory_calculator_configuration) do
    { 'memory_sizes'      => { 'metaspace' => '64m..',
                               'permgen'   => '64m..' },
      'memory_heuristics' => { 'heap'      => '75',
                               'metaspace' => '10',
                               'permgen'   => '10',
                               'stack'     => '5',
                               'native'    => '10' },
      'memory_initials'   => { 'heap'      => '100%',
                               'metaspace' => '100%',
                               'permgen'   => '100%' } }
  end

  it 'always supports' do
    expect(component.supports?).to be
  end

  it 'creates submodules' do
    allow_any_instance_of(StubOpenJDKLike).to receive(:supports?).and_return false

    allow(JavaBuildpack::Jre::OpenJDKLikeJre)
      .to receive(:new).with(sub_configuration_context(jre_configuration).merge(component_name: 'Stub Open JDK Like'))
    allow(JavaBuildpack::Jre::OpenJDKLikeMemoryCalculator)
      .to receive(:new).with(sub_configuration_context(memory_calculator_configuration))

    component.sub_components context
  end

  it 'returns command' do
    java_home.version = version_7
    expect(component.command).to eq('CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_like/bin/' \
                                    'java-buildpack-memory-calculator-0.0.0 -memorySizes=permgen:64m.. ' \
                                    '-memoryWeights=heap:75,permgen:10,stack:5,native:10 ' \
                                    '-memoryInitials=heap:100%,permgen:100% ' \
                                    '-totMemory=$MEMORY_LIMIT)')
  end

end

class StubOpenJDKLike < JavaBuildpack::Jre::OpenJDKLike

  public :command, :sub_components

  def supports?
    super
  end

end

def sub_configuration_context(configuration)
  c                 = context.clone
  c[:configuration] = configuration
  c
end
