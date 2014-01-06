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
require 'java_buildpack/component/immutable_java_home'

describe JavaBuildpack::Component::ImmutableJavaHome do

  let(:delegate) { double('delegate', root: Pathname.new('test-java-home')) }

  let(:immutable_java_home) { described_class.new delegate, Pathname.new('.') }

  it 'should return the JAVA_HOME as an environment variable' do
    expect(immutable_java_home.as_env_var).to eq('JAVA_HOME=$PWD/test-java-home')
  end

  it 'should set JAVA_HOME environment variable' do
    immutable_java_home.do_with do
      expect(ENV['JAVA_HOME']).to eq('test-java-home')
    end
  end

  it 'should return the qualified delegate root' do
    expect(immutable_java_home.root).to eq('$PWD/test-java-home')
  end

end
