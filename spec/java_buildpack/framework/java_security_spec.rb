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
require 'fileutils'
require 'java_buildpack/framework/java_security'

describe JavaBuildpack::Framework::JavaSecurity do
  include_context 'component_helper'

  it 'adds extension directories to system properties' do
    component.release

    expect(java_opts).to include('-Djava.ext.dirs=$PWD/.java-buildpack/java_security/test-extension-directory-1:' \
                                         '$PWD/.java-buildpack/java_security/test-extension-directory-2')
  end

  it 'writes security provider security properties' do
    component.compile

    expect(sandbox + 'java.security').to exist
    expect(File.read(sandbox + 'java.security'))
      .to eq File.read('spec/fixtures/framework_java_security_security_providers')
  end

  it 'writes networking security properties' do
    networking.networkaddress_cache_ttl = -1
    networking.networkaddress_cache_negative_ttl = -2

    component.compile

    expect(sandbox + 'java.security').to exist
    expect(File.read(sandbox + 'java.security')).to eq File.read('spec/fixtures/framework_java_security_networking')
  end

  it 'adds security properties to system properties' do
    component.release

    expect(java_opts).to include('-Djava.security.properties=$PWD/.java-buildpack/java_security/' \
                                 'java.security')
  end

end
