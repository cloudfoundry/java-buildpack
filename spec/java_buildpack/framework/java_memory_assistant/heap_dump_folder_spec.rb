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
require 'java_buildpack/framework/java_memory_assistant/heap_dump_folder'

describe JavaBuildpack::Framework::JavaMemoryAssistantHeapDumpFolder do
  include_context 'application_helper'
  include_context 'component_helper'
  include_context 'logging_helper'

  let(:logger) { described_class.instance.get_logger String }

  context do
    let(:vcap_application) do
      {
        'space_name' => '1234567890',
        'space_id' => '0987654321',
        'application_name' => 'abcdefghi',
        'application_id' => 'ihgfedcba'
      }
    end

    let(:configuration) do
      {
        'heap_dump_folder' => nil
      }
    end

    it 'uses the default for \'jma.heap_dump_folder\' if no value is specified', :enable_log_file, log_level: 'INFO' do

      component.release

      expect(java_opts).to include('-Djma.heap_dump_folder="1234567890-09876543/abcdefghi-ihgfedcb"')
      expect(environment_variables).to include('JMA_HEAP_DUMP_FOLDER=1234567890-09876543/abcdefghi-ihgfedcb')

      expect(log_contents).to match(%r{Heap dumps will be stored under '1234567890-09876543/abcdefghi-ihgfedcb'})
    end

  end

  context do
    let(:configuration) do
      {
        'heap_dump_folder' => 'test/folder'
      }
    end

    it 'adds \'jma.heap_dump_folder\' with verbatim value', :enable_log_file, log_level: 'INFO' do

      component.release

      expect(java_opts).to include('-Djma.heap_dump_folder="test/folder"')
      expect(environment_variables).to include('JMA_HEAP_DUMP_FOLDER=test/folder')

      expect(log_contents).to match(%r{Heap dumps will be stored under \'test/folder\'})
    end

  end

  context do
    let(:configuration) do
      {
        'heap_dump_folder' => 'test/folder'
      }
    end

    before do
      allow(services).to receive(:find_service).with('heap-dump')
                                               .and_return('volume_mounts' =>
                                                 [
                                                   {
                                                     'container_dir' => '/my_volume',
                                                     'mode'          => 'rw'
                                                   }
                                                 ])
    end

    it 'adds \'jma.heap_dump_folder\' with volume container_dir as path root', :enable_log_file, log_level: 'INFO' do

      component.release

      expect(java_opts).to include('-Djma.heap_dump_folder="/my_volume/test/folder"')
      expect(environment_variables).to include('JMA_HEAP_DUMP_FOLDER=/my_volume/test/folder')

      expect(log_contents).to match(%r{Heap dumps will be stored under \'/my_volume/test/folder\'})
    end

  end

  context do
    let(:configuration) do
      {
        'heap_dump_folder' => 'test/folder'
      }
    end

    before do
      allow(services).to receive(:find_service).with('heap-dump')
                                               .and_return('volume_mounts' =>
                                                 [
                                                   {
                                                     'container_dir' => '/my_volume',
                                                     'mode'          => 'r'
                                                   }
                                                 ])
    end

    it 'fails if volume does not have write mode active', :enable_log_file, log_level: 'DEBUG' do
      expect { component.release } .to raise_error 'Volume mounted under \'/my_volume\' not in write mode'
      expect(log_contents).not_to match(/Heap dumps will be stored under/)
    end

  end

end
