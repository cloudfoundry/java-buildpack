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
require 'component_helper'
require 'java_buildpack/framework/your_kit_profiler'

describe JavaBuildpack::Framework::YourKitProfiler do
  include_context 'with component help'

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => true } }

    it 'detects when enabled' do
      expect(component.detect).to eq("your-kit-profiler=#{version}")
    end

    it 'downloads YourKit agent',
       cache_fixture: 'stub-your-kit-profiler.so' do

      component.compile

      expect(sandbox + "your_kit_profiler-#{version}").to exist
    end

    context do
      it 'updates JAVA_OPTS' do
        component.release

        # rubocop:disable Layout/LineLength
        expect(java_opts).to include("-agentpath:$PWD/.java-buildpack/your_kit_profiler/your_kit_profiler-#{version}=" \
                                     'dir=$PWD/.java-buildpack/your_kit_profiler/snapshots,logdir=$PWD/.java-buildpack/your_kit_profiler/logs,' \
                                     'port=10001,sessionname=test-application-name')
        # rubocop:enable Layout/LineLength
      end

      context do
        let(:configuration) { super().merge 'port' => 10_002 }

        it 'adds port from configuration to JAVA_OPTS if specified' do
          component.release

          # rubocop:disable Layout/LineLength
          expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/your_kit_profiler/your_kit_profiler-' \
                                       "#{version}=dir=$PWD/.java-buildpack/your_kit_profiler/snapshots,logdir=$PWD/.java-buildpack/" \
                                       'your_kit_profiler/logs,port=10002,sessionname=test-application-name')
          # rubocop:enable Layout/LineLength
        end
      end

      context do
        let(:configuration) { super().merge 'default_session_name' => 'alternative-session-name' }

        it 'adds session name from configuration to JAVA_OPTS if specified' do
          component.release

          # rubocop:disable Layout/LineLength
          expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/your_kit_profiler/your_kit_profiler-' \
                                       "#{version}=dir=$PWD/.java-buildpack/your_kit_profiler/snapshots,logdir=$PWD/.java-buildpack/" \
                                       'your_kit_profiler/logs,port=10001,sessionname=alternative-session-name')
          # rubocop:enable Layout/LineLength
        end
      end

    end

  end

end
