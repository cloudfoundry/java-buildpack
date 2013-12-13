# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

  it 'should add a qualified javaagent to the collection' do
    opts.add_javaagent droplet.sandbox + 'test-java-agent'

    expect(opts).to include('-javaagent:$PWD/.java-buildpack/java_opts/test-java-agent')
  end

  it 'should add a qualified system property to the collection' do
    opts.add_system_property 'test-key', droplet.sandbox

    expect(opts).to include('-Dtest-key=$PWD/.java-buildpack/java_opts')
  end

  it 'should add a system property to the collection' do
    opts.add_system_property 'test-key', 'test-value'

    expect(opts).to include('-Dtest-key=test-value')
  end

  it 'should add a qualified option to the collection' do
    opts.add_option 'test-key', droplet.sandbox

    expect(opts).to include('test-key=$PWD/.java-buildpack/java_opts')
  end

  it 'should add a option to the collection' do
    opts.add_option 'test-key', 'test-value'

    expect(opts).to include('test-key=test-value')
  end

  it 'should render the collection as an environment variable' do
    opts.add_option 'test-key-2', 'test-value-2'
    opts.add_system_property 'test-key-1', 'test-value-1'

    expect(opts.as_env_var).to eq('JAVA_OPTS="-Dtest-key-1=test-value-1 test-key-2=test-value-2"')
  end

end
