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
require 'java_buildpack/jre/open_jdk_like_security_providers'

describe JavaBuildpack::Jre::OpenJDKLikeSecurityProviders do
  include_context 'component_helper'

  it 'does not add extension directories with no JRE default' do
    component.release

    expect(extension_directories).to contain_exactly(sandbox + 'test-extension-directory-1',
                                                     sandbox + 'test-extension-directory-2')
  end

  it 'adds security providers' do
    FileUtils.mkdir_p(java_home.root + 'lib/security')
    FileUtils.cp 'spec/fixtures/java.security', java_home.root + 'lib/security'

    component.compile

    expect(security_providers).to eq %w[test-security-provider-1
                                        test-security-provider-2
                                        sun.security.provider.Sun
                                        sun.security.rsa.SunRsaSign sun.security.ec.SunEC
                                        com.sun.net.ssl.internal.ssl.Provider
                                        com.sun.crypto.provider.SunJCE
                                        sun.security.jgss.SunProvider
                                        com.sun.security.sasl.Provider
                                        org.jcp.xml.dsig.internal.dom.XMLDSigRI
                                        sun.security.smartcardio.SunPCSC
                                        apple.security.AppleProvider]
  end

  it 'adds extension directories with JRE default to system properties' do
    FileUtils.mkdir_p(java_home.root + 'lib/security/java.security')

    component.release

    expect(extension_directories).to include(java_home.root + 'lib/ext')
  end

  it 'adds extension directories with Server JRE default to system properties' do
    FileUtils.mkdir_p(java_home.root + 'jre/lib/security/java.security')

    component.release

    expect(extension_directories).to include(java_home.root + 'jre/lib/ext')
  end

end
