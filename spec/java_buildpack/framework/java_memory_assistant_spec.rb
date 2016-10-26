# Encoding: utf-8
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
require 'application_helper'
require 'component_helper'
require 'logging_helper'
require 'java_buildpack/framework/java_memory_assistant'

describe JavaBuildpack::Framework::JavaMemoryAssistant do
  include_context 'application_helper'
  include_context 'component_helper'
  include_context 'logging_helper'

  let(:vcap_application) do
    {
      'application_name' => 'testapp',
      'space_id' => '4f7f0547-8637-4109-9d4e-2242b410f452',
      'instance_index' => '42',
      'instance_id' => '406beca7-7692-41f4-9482-f32ae0a1da93'
    }
  end
  let(:max_dump_count) { StringIO.new }
  let(:s3_config_buffer) { StringIO.new }

  before do
    allow(File).to receive(:open)
      .with(droplet_sandbox_path('max_dump_count'), 'w+')
      .and_yield(max_dump_count)

    allow(File).to receive(:open)
      .with(droplet_sandbox_path('s3.config'), 'w+')
      .and_yield(s3_config_buffer)
  end

  context do

    let(:configuration) do
      {
        'enabled' => false
      }
    end

    it 'does not activate the agent if it is disabled in the configuration' do
      expect(component.detect).to eq(nil)
    end

  end

  context do

    let(:configuration) do
      {
        'enabled' => true,
        'check_interval' => '5s',
        'max_frequency' => '1/1m',
        'max_dump_count' => 1,
        'thresholds' => {
          'heap' => 90,
          'old_gen' => 90
        }
      }
    end

    let(:version) { '1.2.3' }

    it 'updates JAVA_OPTS with default values' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-1.2.3.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.heap_dump_name=4f7f05_testapp_%env:CF_INSTANCE_INDEX%_%ts:' \
        'yyyyMMddmmssSS%_%env:CF_INSTANCE_GUID%.hprof')

      expect(java_opts).to include('-Djma.check_interval=5s')
      expect(java_opts).to include('-Djma.max_frequency=1/1m')

      expect(java_opts).to include('-Djma.command.interpreter=/bin/sh')
      expect(java_opts).to include('-Djma.execute.before=$PWD/.java-buildpack/java_memory_assistant/' \
        'bin/clean-up.sh')

      expect(java_opts).to include('-Djma.thresholds.heap=90')
      expect(java_opts).to include('-Djma.thresholds.old_gen=90')

      expect(File).to have_received(:open).with(droplet_sandbox_path('max_dump_count'), 'w+')
      expect(max_dump_count.string).to eq('1')

      expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
      expect(s3_config_buffer.string).to eq('')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'check_interval' => '10m',
        'max_frequency' => '4/10h',
        'heap_dump_folder' => 'test/folder',
        'max_dump_count' => 42,
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

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.heap_dump_name=4f7f05_testapp_%env:CF_INSTANCE_INDEX%_%ts:' \
        'yyyyMMddmmssSS%_%env:CF_INSTANCE_GUID%.hprof')
      expect(java_opts).to include('-Djma.check_interval=10m')
      expect(java_opts).to include('-Djma.max_frequency=4/10h')
      expect(java_opts).to include('-Djma.heap_dump_folder="test/folder"')
      expect(java_opts).to include('-Djma.log_level=DEBUG')
      expect(java_opts).to include('-Djma.thresholds.heap=60')
      expect(java_opts).to include('-Djma.thresholds.code_cache=30')
      expect(java_opts).to include('-Djma.thresholds.metaspace=5')
      expect(java_opts).to include('-Djma.thresholds.perm_gen=45.5')
      expect(java_opts).to include('-Djma.thresholds.eden=90')
      expect(java_opts).to include('-Djma.thresholds.survivor=95.5')
      expect(java_opts).to include('-Djma.thresholds.old_gen=30')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'WARN'
      }
    end

    let(:version) { '0.1.0' }

    it 'updates JAVA_OPTS maps log-level WARN to WARNING' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=WARNING')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'INFO'
      }
    end

    let(:version) { '0.1.0' }

    it 'updates JAVA_OPTS maps log-level INFO to INFO' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=INFO')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'ERROR'
      }
    end

    let(:version) { '0.1.0' }

    it 'updates JAVA_OPTS maps log-level ERROR to ERROR' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=ERROR')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'FATAL'
      }
    end

    let(:version) { '0.1.0' }

    it 'updates JAVA_OPTS maps log-level FATAL to ERROR' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/java_memory_assistant/' \
        'java_memory_assistant-0.1.0.jar')

      expect(java_opts).to include('-Djma.enabled=true')
      expect(java_opts).to include('-Djma.log_level=ERROR')
    end

  end

  context do
    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'debug'
      }
    end

    let(:version) { '0.1.0' }

    it 'fails if log_level is not recognized' do
      expect { component.release }.to raise_exception 'Invalid value of the \'log_level\'' \
        ' property: \'debug\''
    end

  end

  context do
    let(:credentials) { nil }

    before do
      allow(services).to receive(:find_service).with('jma_upload_S3')
        .and_return(nil)
    end

    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'DEBUG'
      }
    end

    let(:version) { '0.1.0' }

    it 'logs a debug statement reporting that S3 is not activated if no service is bound',
       :enable_log_file do
      component.release

      expect(log_contents).to match(/No 'jma_upload_S3' service bound, skipping S3 upload/)
      expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
    end
  end

  context do
    let(:credentials) { nil }

    before do
      allow(services).to receive(:find_service).with('jma_upload_S3')
        .and_return('credentials' => credentials)
    end

    let(:configuration) do
      {
        'enabled' => true,
        'log_level' => 'INFO'
      }
    end

    let(:version) { '0.1.0' }

    it 'fails if the S3 service is bound without credentials' do
      expect { component.release }.to raise_exception 'No credentials are available for the ' \
        '\'jma_upload_S3\' service bound to this application'

      expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
    end

    context do
      let(:credentials) { {} }

      it 'fails if the credentials of the S3 service are empty' do
        expect { component.release }.to raise_exception 'No \'bucket\' entry found in the credentials ' \
          'for the \'jma_upload_S3\' service'

        expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
      end
    end

    context do
      let(:credentials) { { 'bucket' => 'my_bucket' } }

      it 'fails if the credentials of the S3 service do not contain the \'region\' property' do
        expect { component.release }.to raise_exception 'No \'region\' entry found in the credentials ' \
          'for the \'jma_upload_S3\' service'

        expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
      end
    end

    context do
      let(:credentials) { { 'bucket' => 'my_bucket', 'region' => 'eu-central-1' } }

      it 'fails if the credentials of the S3 service do not contain the \'key\' property' do
        expect { component.release }.to raise_exception 'No \'key\' entry found in the credentials ' \
          'for the \'jma_upload_S3\' service'

        expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
      end
    end

    context do
      let(:credentials) { { 'bucket' => 'my_bucket', 'region' => 'eu-central-1', 'key' => 'my_key' } }

      it 'fails if the credentials of the S3 service do not contain the \'secret\' property' do
        expect { component.release }.to raise_exception 'No \'secret\' entry found in the credentials ' \
          'for the \'jma_upload_S3\' service'

        expect(File).not_to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
      end
    end

    context do
      let(:credentials) do
        {
          'bucket' => 'my_bucket',
          'region' => 'eu-central-1',
          'key' => 'my_key',
          'secret' => 'my_secret'
        }
      end

      it 'configures the S3 upload script to run after heap dumps with logging activated' do
        component.release

        expect(File).to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
        expect(s3_config_buffer.string).to eq(<<-eos
BUCKET='my_bucket'
AWS_ACCESS_KEY='my_key'
AWS_SECRET_KEY='my_secret'
AWS_REGION='eu-central-1'
LOG=true
KEEP_IN_CONTAINER=false
eos
          ) # rubocop:disable Style/ClosingParenthesisIndentation

        expect(java_opts).to include('-Djma.execute.after=$PWD/.java-buildpack/java_memory_assistant' \
          '/bin/upload-to-s3.sh')
      end
    end

    context do

      let(:configuration) do
        {
          'enabled' => true,
          'log_level' => 'ERROR'
        }
      end

      let(:credentials) do
        {
          'bucket' => 'my_bucket',
          'region' => 'eu-central-1',
          'key' => 'my_key',
          'secret' => 'my_secret'
        }
      end

      it 'configures the S3 upload script to run after heap dumps with logging disactivated' do
        component.release

        expect(File).to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
        expect(s3_config_buffer.string).to eq(<<-eos
BUCKET='my_bucket'
AWS_ACCESS_KEY='my_key'
AWS_SECRET_KEY='my_secret'
AWS_REGION='eu-central-1'
LOG=false
KEEP_IN_CONTAINER=false
eos
          ) # rubocop:disable Style/ClosingParenthesisIndentation

        expect(java_opts).to include('-Djma.execute.after=$PWD/.java-buildpack/java_memory_assistant' \
          '/bin/upload-to-s3.sh')
      end

    end

    context do

      let(:configuration) do
        {
          'enabled' => true,
          'log_level' => 'ERROR'
        }
      end

      let(:credentials) do
        {
          'bucket' => 'my_bucket',
          'region' => 'eu-central-1',
          'key' => 'my_key',
          'secret' => 'my_secret',
          'keep_in_container' => 'true'
        }
      end

      it 'configures the S3 upload script to run after heap dumps with keep_in_container activated',
         :enable_log_file do

        component.release

        expect(File).to have_received(:open).with(droplet_sandbox_path('s3.config'), 'w+')
        expect(s3_config_buffer.string).to eq(<<-eos
BUCKET='my_bucket'
AWS_ACCESS_KEY='my_key'
AWS_SECRET_KEY='my_secret'
AWS_REGION='eu-central-1'
LOG=false
KEEP_IN_CONTAINER=true
eos
          ) # rubocop:disable Style/ClosingParenthesisIndentation

        expect(java_opts).to include('-Djma.execute.after=$PWD/.java-buildpack/java_memory_assistant' \
          '/bin/upload-to-s3.sh')
        expect(java_opts).to include('-Djma.execute.on_shutdown=$PWD/.java-buildpack/java_memory_assistant' \
          '/bin/kill-upload-to-s3.sh')

        expect(log_contents).to match(/Upload of heap dumps configured to S3 bucket 'my_bucket'/)
      end
    end

  end

end
