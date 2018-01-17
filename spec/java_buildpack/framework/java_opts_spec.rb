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
require 'java_buildpack/framework/java_opts'

describe JavaBuildpack::Framework::JavaOpts do
  include_context 'with component help'

  context do
    let(:configuration) { { 'java_opts' => '-Xmx1024M' } }

    it 'detects with java.opts configuration' do
      expect(component.detect).to eq('java-opts')
    end
  end

  context do
    let(:configuration) { { 'from_environment' => true } }
    let(:environment) { { 'JAVA_OPTS' => '-Dalpha=bravo' } }

    it 'detects with ENV and with from_environment configuration' do
      expect(component.detect).to eq('java-opts')
    end
  end

  context do
    let(:configuration) do
      { 'java_opts' => '-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,server=y,address=8000,suspend=y ' \
          "-XX:OnOutOfMemoryError='kill -9 %p'" }
    end

    it 'adds split java_opts to context' do
      component.release
      expect(java_opts).to include('-Xdebug')
      expect(java_opts).to include('-Xnoagent')
      expect(java_opts).to include('-Xrunjdwp:transport=dt_socket,server\=y,address\=8000,suspend\=y')
      expect(java_opts).to include('-XX:OnOutOfMemoryError=kill\ -9\ \%p')
    end
  end

  context do
    let(:configuration) do
      { 'java_opts' => '-Dtest=!£%^&*()<>[]{};~`' }
    end

    it 'escapes special characters' do
      component.release
      expect(java_opts).to include('-Dtest=\!\£\%\^\&\*\(\)\<\>\[\]\{\}\;\~\`')
    end
  end

  context do
    let(:configuration) do
      { 'java_opts' => '-Dtest=$DOLLAR\\\SLASH' }
    end

    it 'does not escape the shell variable character from configuration' do
      component.release
      expect(java_opts).to include('-Dtest=$DOLLAR\SLASH')
    end
  end

  context do
    let(:configuration) do
      { 'java_opts' => '-Dtest=something.\\\$dollar.\\\\\\\slash' }
    end

    it 'can escape non-escaped characters ' do
      component.release
      expect(java_opts).to include('-Dtest=something.\\$dollar.\\\slash')
    end
  end

  context do
    let(:configuration) do
      { 'java_opts' => '-javaagent:agent.jar=port=$PORT,host=localhost' }
    end

    it 'escapes equal signs after the first one' do
      component.release
      expect(java_opts).to include('-javaagent:agent.jar=port\\=$PORT,host\\=localhost')
    end
  end

  context do
    let(:configuration) { { 'from_environment' => true } }

    it 'includes $JAVA_OPTS with from_environment' do
      component.release
      expect(java_opts).to include('$JAVA_OPTS')
    end
  end

  it 'does not include $JAVA_OPTS without from_environment' do
    component.release
    expect(java_opts).not_to include('$JAVA_OPTS')
  end

end
