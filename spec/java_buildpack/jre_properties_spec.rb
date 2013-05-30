# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

describe JavaBuildpack::JreProperties do

  CANDIDATE_VENDOR = 'candidate-vendor'

  CANDIDATE_VERSION = 'candidate-version'

  RESOLVED_PATH = 'resolved-path'

  RESOLVED_ROOT = 'resolved-root'

  RESOLVED_VENDOR = 'resolved-vendor'

  RESOLVED_VERSION = 'resolved-version'

  RESOLVED_URI = "#{RESOLVED_ROOT}/#{RESOLVED_PATH}"

  it 'returns the resolved vendor, version, and uri' do
    YAML.stub(:load_file).with('config/jres.yml').and_return(RESOLVED_VENDOR => RESOLVED_ROOT)
    JavaBuildpack::JreProperties.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
    JavaBuildpack::ValueResolver.any_instance.stub(:resolve).with('JAVA_RUNTIME_VENDOR', 'java.runtime.vendor').and_return(CANDIDATE_VENDOR)
    JavaBuildpack::ValueResolver.any_instance.stub(:resolve).with('JAVA_RUNTIME_VERSION', 'java.runtime.version').and_return(CANDIDATE_VERSION)
    JavaBuildpack::VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)
    JavaBuildpack::VersionResolver.stub(:resolve).with(CANDIDATE_VERSION, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

    jre_properties = JavaBuildpack::JreProperties.new('spec/fixtures/no_system_properties')

    expect(jre_properties.vendor).to eq(RESOLVED_VENDOR)
    expect(jre_properties.version).to eq(RESOLVED_VERSION)
    expect(jre_properties.uri).to eq(RESOLVED_URI)
  end

end
