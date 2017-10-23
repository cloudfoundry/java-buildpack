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
require 'component_helper'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/open_jdk_like_jre'
require 'resolv'

describe JavaBuildpack::Jre::OpenJDKLikeJre do
  include_context 'component_helper'

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }

  it 'detects with id of openjdk_like_jre-<version>' do
    expect(component.detect).to eq("open-jdk-like-jre=#{version}")
  end

  it 'extracts Java from a GZipped TAR',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.compile

    expect(sandbox + 'bin/java').to exist
  end

  it 'adds the JAVA_HOME to java_home' do
    component

    expect(java_home.root).to eq(sandbox)
  end

  it 'adds java.io.tmpdir to java_opts' do
    component.detect
    component.release

    expect(java_opts).to include('-Djava.io.tmpdir=$TMPDIR')
  end

  it 'does not disable dns caching if no BOSH DNS',
     cache_fixture: 'stub-java.tar.gz' do

    component.detect
    component.compile

    expect(networking.networkaddress_cache_ttl).not_to be
    expect(networking.networkaddress_cache_negative_ttl).not_to be
  end

  it 'disables dns caching if BOSH DNS',
     cache_fixture: 'stub-java.tar.gz' do

    allow_any_instance_of(Resolv::DNS::Config).to receive(:nameserver_port).and_return([['169.254.0.2', 53]])

    component.detect
    component.compile

    expect(networking.networkaddress_cache_ttl).to eq 0
    expect(networking.networkaddress_cache_negative_ttl).to eq 0
  end

end
