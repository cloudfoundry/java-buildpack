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
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/util/tokenized_version'
require 'pathname'

describe JavaBuildpack::Component::MutableJavaHome do

  let(:path) { Pathname.new('foo/bar') }

  let(:java_version) { JavaBuildpack::Util::TokenizedVersion.new('1.2.3_u04') }

  let(:mutable_java_home) { described_class.new }

  it 'saves root' do
    mutable_java_home.root = path
    expect(mutable_java_home.root).to eq(path)
  end

  it 'saves version' do
    mutable_java_home.version = java_version
    expect(mutable_java_home.version).to eq(java_version)
  end

  it 'recognizes Java 6' do
    mutable_java_home.version = JavaBuildpack::Util::TokenizedVersion.new('1.6.0')
    expect(mutable_java_home.java_8_or_later?).not_to be
  end

  it 'recognizes Java 7' do
    mutable_java_home.version = JavaBuildpack::Util::TokenizedVersion.new('1.7.0')
    expect(mutable_java_home.java_8_or_later?).not_to be
  end

  it 'recognizes Java 8' do
    mutable_java_home.version = JavaBuildpack::Util::TokenizedVersion.new('1.8.0')
    expect(mutable_java_home.java_8_or_later?).to be
  end

  it 'recognizes Java 9' do
    mutable_java_home.version = JavaBuildpack::Util::TokenizedVersion.new('1.9.0')
    expect(mutable_java_home.java_8_or_later?).to be
  end

end
