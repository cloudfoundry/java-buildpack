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
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/open_jdk_like_memory_calculator'
require 'java_buildpack/util/qualify_path'

describe JavaBuildpack::Jre::OpenJDKLikeMemoryCalculator do
  include_context 'component_helper'
  include JavaBuildpack::Util

  let(:configuration) { { 'stack_threads' => '200' } }

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  let(:version_8) { VERSION_8 = JavaBuildpack::Util::TokenizedVersion.new('1.8.0_+') }

  it 'copies executable to bin directory',
     cache_fixture: 'stub-memory-calculator.tar.gz' do

    allow(component).to receive(:show_settings)

    component.compile

    expect(sandbox + "bin/java-buildpack-memory-calculator-#{version}").to exist
  end

  it 'chmods executable to 0755',
     cache_fixture: 'stub-memory-calculator.tar.gz' do

    allow(component).to receive(:show_settings)

    component.compile

    expect(File.stat(sandbox + "bin/java-buildpack-memory-calculator-#{version}").mode).to eq(0o100755)
  end

  context do

    let(:version) { '3.0.0' }

    it 'copies executable to bin directory from a compressed archive',
       cache_fixture: 'stub-memory-calculator.tar.gz' do

      allow(component).to receive(:show_settings)

      component.compile

      expect(sandbox + "bin/java-buildpack-memory-calculator-#{version}").to exist
    end

    it 'chmods executable to 0755 from a compressed archive',
       cache_fixture: 'stub-memory-calculator.tar.gz' do

      allow(component).to receive(:show_settings)

      component.compile

      expect(File.stat(sandbox + "bin/java-buildpack-memory-calculator-#{version}").mode).to eq(0o100755)
    end

  end

  it 'creates memory calculation command',
     app_fixture: 'jre_memory_calculator_application' do

    java_home.version = version_8

    command = component.memory_calculation_command

    expect(command).to eq('CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_like_memory_calculator/bin/' \
                            'java-buildpack-memory-calculator-0.0.0 -totMemory=$MEMORY_LIMIT -stackThreads=200 ' \
                            '-loadedClasses=2 -poolType=metaspace -vmOptions="$JAVA_OPTS") && echo JVM Memory ' \
                            'Configuration: $CALCULATED_MEMORY && JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY"')
  end

end
