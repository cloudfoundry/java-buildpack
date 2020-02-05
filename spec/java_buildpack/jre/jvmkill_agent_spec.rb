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
require 'java_buildpack/jre/jvmkill_agent'

describe JavaBuildpack::Jre::JvmkillAgent do
  include_context 'with component help'

  it 'copies executable to bin directory',
     cache_fixture: 'stub-jvmkill-agent' do

    component.compile

    expect(sandbox + "bin/jvmkill-#{version}").to exist
  end

  it 'chmods executable to 0755',
     cache_fixture: 'stub-jvmkill-agent' do

    component.compile

    expect(File.stat(sandbox + "bin/jvmkill-#{version}").mode).to eq(0o100755)
  end

  it 'adds agent parameters to the JAVA_OPTS' do
    component.release

    expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jvmkill_agent/bin/jvmkill-0.0.0=printHeapHistogram=1')
  end

  it 'adds heap dump parameter to JAVA_OPTS when volume service available' do
    allow(services).to receive(:one_volume_service?).with(/heap-dump/).and_return(true)
    allow(services).to receive(:find_volume_service).and_return('volume_mounts' =>
                                                           [{ 'container_dir' => 'test-container-dir' }])

    component.release

    expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/jvmkill_agent/bin/jvmkill-0.0.0=' \
                                 'printHeapHistogram=1,heapDumpPath=test-container-dir/test-space-name-test-spa/' \
                                 'test-application-name-test-app/$CF_INSTANCE_INDEX-%FT%T%z-' \
                                 '${CF_INSTANCE_GUID:0:8}.hprof')
  end

end
