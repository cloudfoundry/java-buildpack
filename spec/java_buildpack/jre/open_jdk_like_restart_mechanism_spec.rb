# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/jre/open_jdk_like_restart_mechanism'

describe JavaBuildpack::Jre::OpenJDKLikeRestartMechanism do
  include_context 'component_helper'

  it 'places the killjava script (with appropriately substituted content) in the bin directory',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.compile

    expect(sandbox + 'bin/killjava.sh').to exist
  end

  it 'does not add OnOutOfMemoryError to java_opts when configured with type none' do
    allow(component).to receive(:restart_type).and_return('none')

    component.detect
    component.release

    expect(java_opts).not_to include('-XX:OnOutOfMemoryError=$PWD/.java-buildpack/' \
      'open_jdk_like_restart_mechanism/bin/killjava.sh')
    expect(java_opts).not_to include('-agentpath:$PWD/.java-buildpack/' \
      'open_jdk_like_restart_mechanism/lib/libjvmkill.so')
  end

  it 'adds OnOutOfMemoryError to java_opts for script type' do
    allow(component).to receive(:restart_type).and_return('script')

    component.detect
    component.release

    expect(java_opts).to include('-XX:OnOutOfMemoryError=$PWD/.java-buildpack/' \
      'open_jdk_like_restart_mechanism/bin/killjava.sh')
  end

  it 'downloads the JVMKill native agent',
     cache_fixture: 'stub-jvmkill-archive.zip' do

    allow(component).to receive(:restart_type).and_return('agent')

    component.compile

    expect(sandbox + 'lib/libjvmkill.so').to exist
  end

  it 'adds correct arguments to JAVA_OPTS for agent type',
     cache_fixture: 'stub-jvmkill-archive.zip' do

    allow(component).to receive(:restart_type).and_return('agent')

    component.release

    expect(java_opts).to include('-agentpath:$PWD/.java-buildpack/' \
      'open_jdk_like_restart_mechanism/lib/libjvmkill.so')
  end
end
