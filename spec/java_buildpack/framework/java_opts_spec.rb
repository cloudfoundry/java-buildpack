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
require 'java_buildpack/framework/java_opts'

describe JavaBuildpack::Framework::JavaOpts do
  include_context 'component_helper'

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
    let(:environment) { { 'JAVA_OPTS' => '-Dalpha=bravo' } }

    it 'does not detect with ENV and without from_environment configuration' do
      expect(component.detect).to be_nil
    end
  end

  context do
    let(:configuration) { { 'java_opts' => nil } }

    it 'does not detect with nil java_opts configuration' do
      expect(component.detect).to be_nil
    end
  end

  it 'does not detect without java_opts configuration' do
    expect(component.detect).to be_nil
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
    let(:configuration) { { 'from_environment' => true } }
    let(:environment) { { 'JAVA_OPTS' => '-Dtest=$dollar\\\slash' } }

    it 'does not escape the shell variable character from environment' do
      component.release
      expect(java_opts).to include('-Dtest=$dollar\slash')
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
    let(:configuration) { { 'java_opts' => '-Xms1024M' } }

    it 'raises an error if a -Xms is configured' do
      expect { component.compile }.to raise_error(/-Xms/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-Xmx1024M' } }

    it 'raises an error if a -Xmx is configured' do
      expect { component.compile }.to raise_error(/-Xmx/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-XX:MaxMetaspaceSize=128M' } }

    it 'raises an error if a -XX:MaxMetaspaceSize is configured' do
      expect { component.compile }.to raise_error(/-XX:MaxMetaspaceSize/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-XX:MetaspaceSize=128M' } }

    it 'raises an error if a -XX:MetaspaceSize is configured' do
      expect { component.compile }.to raise_error(/-XX:MetaspaceSize/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-XX:MaxPermSize=128M' } }

    it 'raises an error if a -XX:MaxPermSize is configured' do
      expect { component.compile }.to raise_error(/-XX:MaxPermSize/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-XX:PermSize=128M' } }

    it 'raises an error if a -XX:PermSize is configured' do
      expect { component.compile }.to raise_error(/-XX:PermSize/)
    end
  end

  context do
    let(:configuration) { { 'java_opts' => '-Xss1M' } }

    it 'raises an error if a -Xss is configured' do
      expect { component.compile }.to raise_error(/-Xss/)
    end
  end

  context do
    let(:configuration) { { 'from_environment' => true } }
    let(:environment) { { 'JAVA_OPTS' => '-Dalpha=bravo' } }

    it 'includes values specified in ENV[JAVA_OPTS]' do
      component.release
      expect(java_opts).to include('-Dalpha=bravo')
    end
  end

  context do
    let(:environment) { { 'JAVA_OPTS' => '-Dalpha=bravo' } }

    it 'does not include values specified in ENV[JAVA_OPTS] without from_environment' do
      component.release
      expect(java_opts).not_to include('-Dalpha=bravo')
    end
  end

end
