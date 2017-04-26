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
require 'java_buildpack/component/immutable_java_home'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Component::ImmutableJavaHome do

  let(:delegate) do
    instance_double(JavaBuildpack::Component::MutableJavaHome,
                    root:             Pathname.new('test-java-home'),
                    java_8_or_later?: true,
                    version:          JavaBuildpack::Util::TokenizedVersion.new('1.2.3_u04'))
  end

  let(:immutable_java_home) { described_class.new delegate, Pathname.new('.') }

  it 'returns the JAVA_HOME as an environment variable' do
    expect(immutable_java_home.as_env_var).to eq('JAVA_HOME=$PWD/test-java-home')
  end

  it 'returns the qualified delegate root' do
    expect(immutable_java_home.root.to_s).to eq('test-java-home')
  end

  it 'returns the delegate version' do
    expect(immutable_java_home.version).to eq(%w[1 2 3 u04])
  end

  it 'returns the delegate Java 8 or later' do
    expect(immutable_java_home.java_8_or_later?).to be
  end

end
