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
require 'droplet_helper'
require 'java_buildpack/component/java_opts'

describe JavaBuildpack::Component::JavaOpts do
  include_context 'droplet_helper'

  let(:opts) { described_class.new droplet.root }

  it 'adds a qualified javaagent to the collection' do
    opts.add_javaagent droplet.sandbox + 'test-java-agent'

    expect(opts).to include('-javaagent:$PWD/.java-buildpack/java_opts/test-java-agent')
  end

  it 'adds a qualified agentpath to the collection' do
    opts.add_agentpath droplet.sandbox + 'test-agentpath'

    expect(opts).to include('-agentpath:$PWD/.java-buildpack/java_opts/test-agentpath')
  end

  it 'adds a qualified agentpath with properties to the collection' do
    opts.add_agentpath_with_props(droplet.sandbox + 'test-agentpath', 'key1' => 'value1', 'key2' => 'value2')

    expect(opts).to include('-agentpath:$PWD/.java-buildpack/java_opts/test-agentpath=key1=value1,key2=value2')
  end

  it 'adds a qualified system property to the collection' do
    opts.add_system_property 'test-key', droplet.sandbox

    expect(opts).to include('-Dtest-key=$PWD/.java-buildpack/java_opts')
  end

  it 'adds a system property to the collection' do
    opts.add_system_property 'test-key', 'test-value'

    expect(opts).to include('-Dtest-key=test-value')
  end

  it 'adds a bootclasspath property to the collection' do
    opts.add_bootclasspath_p droplet.sandbox + 'test-bootclasspath'

    expect(opts).to include('-Xbootclasspath/p:$PWD/.java-buildpack/java_opts/test-bootclasspath')
  end

  it 'adds a qualified option to the collection' do
    opts.add_option 'test-key', droplet.sandbox

    expect(opts).to include('test-key=$PWD/.java-buildpack/java_opts')
  end

  it 'adds a option to the collection' do
    opts.add_option 'test-key', 'test-value'

    expect(opts).to include('test-key=test-value')
  end

  it 'renders the collection as an environment variable' do
    opts.add_option 'test-key-2', 'test-value-2'
    opts.add_system_property 'test-key-1', 'test-value-1'

    expect(opts.as_env_var).to eq('JAVA_OPTS="test-key-2=test-value-2 -Dtest-key-1=test-value-1"')
  end

end
