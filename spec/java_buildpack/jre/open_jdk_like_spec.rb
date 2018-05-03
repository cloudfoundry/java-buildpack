# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/jre/open_jdk_like_security_providers'

describe JavaBuildpack::Jre::OpenJDKLike do
  include_context 'with component help'

  let(:component) { StubOpenJDKLike.new context }

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:version_7) { VERSION_7 = JavaBuildpack::Util::TokenizedVersion.new('1.7.0_+') }

  let(:version_8) { VERSION_8 = JavaBuildpack::Util::TokenizedVersion.new('1.8.0_+') }

  let(:configuration) do
    { 'jre'               => jre_configuration,
      'memory_calculator' => memory_calculator_configuration,
      'jvmkill_agent'     => jvmkill_agent_configuration }
  end

  let(:jre_configuration) { instance_double('jre_configuration') }

  let(:jvmkill_agent_configuration) { {} }

  let(:memory_calculator_configuration) { { 'stack_threads' => '200' } }

  it 'always supports' do
    expect(component.supports?).to be
  end

  it 'creates submodules' do
    allow_any_instance_of(StubOpenJDKLike).to receive(:supports?).and_return false

    allow(JavaBuildpack::Jre::JvmkillAgent)
      .to receive(:new).with(sub_configuration_context(jvmkill_agent_configuration))
    allow(JavaBuildpack::Jre::OpenJDKLikeJre)
      .to receive(:new).with(sub_configuration_context(jre_configuration).merge(component_name: 'Stub Open JDK Like'))
    allow(JavaBuildpack::Jre::OpenJDKLikeMemoryCalculator)
      .to receive(:new).with(sub_configuration_context(memory_calculator_configuration))
    allow(JavaBuildpack::Jre::OpenJDKLikeSecurityProviders)
      .to receive(:new).with(context)

    component.sub_components context
  end

  it 'returns command for Java 7' do
    java_home.version = version_7
    expect(component.command).to eq('CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_like/bin/' \
                                    'java-buildpack-memory-calculator-0.0.0 -totMemory=$MEMORY_LIMIT' \
                                    ' -loadedClasses=0 -poolType=permgen -stackThreads=200 -vmOptions="$JAVA_OPTS")' \
                                    ' && echo JVM Memory Configuration: $CALCULATED_MEMORY && ' \
                                    'JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"')

  end

  it 'returns command for Java 8' do
    java_home.version = version_8
    expect(component.command).to eq('CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_like/bin/' \
                                    'java-buildpack-memory-calculator-0.0.0 -totMemory=$MEMORY_LIMIT' \
                                    ' -loadedClasses=0 -poolType=metaspace -stackThreads=200 -vmOptions="$JAVA_OPTS")' \
                                    ' && echo JVM Memory Configuration: $CALCULATED_MEMORY && ' \
                                    'JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"')

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
