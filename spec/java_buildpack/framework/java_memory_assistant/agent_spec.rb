# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'component_helper'
require 'logging_helper'
require 'java_buildpack/component/environment_variables'
require 'java_buildpack/framework/java_memory_assistant/agent'

describe JavaBuildpack::Framework::JavaMemoryAssistantAgent do
  include_context 'with application help'
  include_context 'with component help'
  include_context 'with logging help'

  let(:vcap_application) do
    {
      'instance_index' => '42',
      'instance_id' => '406beca7-7692-41f4-9482-f32ae0a1da93'
    }
  end

  context do

    let(:configuration) do
      {
        'check_interval' => '5s',
        'max_frequency' => '1/1m',
        'thresholds' => {
          'heap' => 90,
          'old_gen' => 90
        }
      }
    end

    let(:version) { '1.2.3' }

    it 'updates JAVA_OPTS with default values' do
      component.release

      expect(java_opts).not_to include('--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED')

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant_agent/' \
                                   'java-memory-assistant-1.2.3.jar')
      expect(java_opts).to include('-Djma.enabled=true')

      expect(java_opts).to include('-Djma.check_interval=5s')
      expect(java_opts).to include('\'-Djma.max_frequency=1/1m\'')

      expect(java_opts).to include('\'-Djma.thresholds.heap=90\'')
      expect(java_opts).to include('\'-Djma.thresholds.old_gen=90\'')

    end

    context do

      let(:java_home_delegate) do
        delegate         = JavaBuildpack::Component::MutableJavaHome.new
        delegate.root    = app_dir + '.test-java-home'
        delegate.version = JavaBuildpack::Util::TokenizedVersion.new('1.8.0_55')

        delegate
      end

      it 'does not add the --add-opens on Java 8' do
        component.release

        expect(java_opts).not_to include('--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED')
      end

    end

    context do

      let(:java_home_delegate) do
        delegate         = JavaBuildpack::Component::MutableJavaHome.new
        delegate.root    = app_dir + '.test-java-home'
        delegate.version = JavaBuildpack::Util::TokenizedVersion.new('9.0.1')

        delegate
      end

      it 'adds the --add-opens on Java 11' do
        component.release

        expect(java_opts).to include('--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED')
      end

    end

  end

  context do
    let(:configuration) do
      {
        'check_interval' => '10m',
        'max_frequency' => '4/10h',
        'heap_dump_folder' => 'test/folder',
        'log_level' => 'DEBUG',
        'thresholds' => {
          'heap' => 60,
          'code_cache' => 30,
          'metaspace' => 5,
          'perm_gen' => 45.5,
          'eden' => 90,
          'survivor' => 95.5,
          'old_gen' => 30
        }
      }
    end

    let(:version) { '0.1.0' }

    it 'updates JAVA_OPTS with configured values' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant_agent/' \
                                   'java-memory-assistant-0.1.0.jar')
      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.check_interval=10m')
      expect(java_opts).to include('\'-Djma.max_frequency=4/10h\'')
      expect(java_opts).to include('-Djma.log_level=DEBUG')
      expect(java_opts).to include('\'-Djma.thresholds.heap=60\'')
      expect(java_opts).to include('\'-Djma.thresholds.code_cache=30\'')
      expect(java_opts).to include('\'-Djma.thresholds.metaspace=5\'')
      expect(java_opts).to include('\'-Djma.thresholds.perm_gen=45.5\'')
      expect(java_opts).to include('\'-Djma.thresholds.eden=90\'')
      expect(java_opts).to include('\'-Djma.thresholds.survivor=95.5\'')
      expect(java_opts).to include('\'-Djma.thresholds.old_gen=30\'')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'debug'
      }
    end

    it 'maps log-level case-insensitive' do
      component.release

      expect(java_opts).to include('-Djma.log_level=DEBUG')
    end

  end

  context do
    let(:configuration) do
      {
        'thresholds' => {
          'heap' => '>600MB',
          'eden' => '< 30MB'
        }
      }
    end

    let(:version) { '0.1.0' }

    it 'escapses redirection characters' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant_agent/' \
                                   'java-memory-assistant-0.1.0.jar')

      expect(java_opts).to include('\'-Djma.thresholds.heap=>600MB\'')
      expect(java_opts).to include('\'-Djma.thresholds.eden=< 30MB\'')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'WARN'
      }
    end

    let(:version) { '0.1.0' }

    it 'maps log-level WARN to WARNING' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant_agent/' \
                                   'java-memory-assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=WARNING')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'INFO'
      }
    end

    let(:version) { '0.1.0' }

    it 'maps log-level INFO to INFO' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant_agent/' \
                                   'java-memory-assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=INFO')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'ERROR'
      }
    end

    it 'maps log-level ERROR to ERROR' do
      component.release

      expect(java_opts).to include('-Djma.log_level=ERROR')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'FATAL'
      }
    end

    it 'maps log-level FATAL to ERROR' do
      component.release

      expect(java_opts).to include('-Djma.log_level=ERROR')
    end

  end

  context do

    let(:configuration) do
      {}
    end

    it 'falls back on JBP log_level when no log_level specified via configuration',
       :enable_log_file, log_level: 'WARN' do
      component.release

      expect(java_opts).to include('-Djma.log_level=WARNING')
    end

  end

  context do
    let(:configuration) do
      {
        'log_level' => 'ciao'
      }
    end

    it 'fails if log_level is not recognized' do
      expect { component.release }.to raise_exception 'Invalid value of the \'log_level\'' \
                                                      ' property: \'ciao\''
    end

  end

end
