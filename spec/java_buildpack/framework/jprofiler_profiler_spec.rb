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
require 'java_buildpack/framework/jprofiler_profiler'

describe JavaBuildpack::Framework::JprofilerProfiler do
  include_context 'with component help'

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => true } }

    it 'detects when enabled' do
      expect(component.detect).to eq("jprofiler-profiler=#{version}")
    end

    it 'downloads YourKit agent',
       cache_fixture: 'stub-jprofiler-profiler.tar.gz' do

      component.compile

      expect(sandbox + 'bin/linux-x64/libjprofilerti.so').to exist
    end

    context do
      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jprofiler_profiler/bin/linux-x64/' \
                                     'libjprofilerti.so=port=8849,nowait')

      end

      context do
        let(:configuration) { super().merge 'port' => 8_850 }

        it 'adds port from configuration to JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jprofiler_profiler/bin/linux-x64/' \
                                       'libjprofilerti.so=port=8850,nowait')
        end
      end

      context do
        let(:configuration) { super().merge 'nowait' => false }

        it 'disables nowait in JAVA_OPTS if specified' do
          component.release

          expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jprofiler_profiler/bin/linux-x64/' \
                                       'libjprofilerti.so=port=8849')
        end
      end

    end

  end

end
