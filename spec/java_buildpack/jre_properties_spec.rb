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

  DEFAULT_VERSION = 'default-version'

  RESOLVED_PATH = 'resolved-path'

  RESOLVED_ROOT = 'resolved-root'

  RESOLVED_VENDOR = 'resolved-vendor'

  RESOLVED_VERSION = 'resolved-version'

  RESOLVED_ID = "jre-#{RESOLVED_VENDOR}-#{RESOLVED_VERSION}"

  RESOLVED_URI = "#{RESOLVED_ROOT}/#{RESOLVED_PATH}"

  let(:value_resolver) { double('ValueResolver') }

  HEAP_SIZE = '64m'

  INVALID_HEAP_SIZE = '64m -Xint'

  it 'returns the resolved id, vendor, version, and uri from uri-only vendor details' do
    JavaBuildpack::ValueResolver.stub(:new).with('spec/fixtures/no_system_properties').and_return(value_resolver)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VENDOR', 'java.runtime.vendor').and_return(CANDIDATE_VENDOR)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VERSION', 'java.runtime.version').and_return(CANDIDATE_VERSION)
    YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => RESOLVED_ROOT)
    JavaBuildpack::VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)
    JavaBuildpack::JreProperties.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
    JavaBuildpack::VersionResolver.stub(:resolve).with(CANDIDATE_VERSION, nil, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

    jre_properties = JavaBuildpack::JreProperties.new('spec/fixtures/no_system_properties')

    expect(jre_properties.id).to eq(RESOLVED_ID)
    expect(jre_properties.vendor).to eq(RESOLVED_VENDOR)
    expect(jre_properties.version).to eq(RESOLVED_VERSION)
    expect(jre_properties.uri).to eq(RESOLVED_URI)
  end

it 'returns the resolved id, vendor, version, and uri from extended vendor details' do
    JavaBuildpack::ValueResolver.stub(:new).with('spec/fixtures/no_system_properties').and_return(value_resolver)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VENDOR', 'java.runtime.vendor').and_return(CANDIDATE_VENDOR)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VERSION', 'java.runtime.version').and_return(CANDIDATE_VERSION)
    YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => {'default_version' => DEFAULT_VERSION, 'repository_root' => RESOLVED_ROOT})
    JavaBuildpack::VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)
    JavaBuildpack::JreProperties.any_instance.stub(:open).with("#{RESOLVED_ROOT}/index.yml").and_return(File.open('spec/fixtures/test-index.yml'))
    JavaBuildpack::VersionResolver.stub(:resolve).with(CANDIDATE_VERSION, DEFAULT_VERSION, [RESOLVED_VERSION]).and_return(RESOLVED_VERSION)

    jre_properties = JavaBuildpack::JreProperties.new('spec/fixtures/no_system_properties')

    expect(jre_properties.id).to eq(RESOLVED_ID)
    expect(jre_properties.vendor).to eq(RESOLVED_VENDOR)
    expect(jre_properties.version).to eq(RESOLVED_VERSION)
    expect(jre_properties.uri).to eq(RESOLVED_URI)
  end

  it 'raises an error if the vendor details are not of a valid structure' do
    JavaBuildpack::ValueResolver.stub(:new).with('spec/fixtures/no_system_properties').and_return(value_resolver)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VENDOR', 'java.runtime.vendor').and_return(CANDIDATE_VENDOR)
    value_resolver.stub(:resolve).with('JAVA_RUNTIME_VERSION', 'java.runtime.version').and_return(CANDIDATE_VERSION)
    YAML.stub(:load_file).with(File.expand_path 'config/jres.yml').and_return(RESOLVED_VENDOR => {'uri' => RESOLVED_ROOT})
    JavaBuildpack::VendorResolver.stub(:resolve).with(CANDIDATE_VENDOR, [RESOLVED_VENDOR]).and_return(RESOLVED_VENDOR)

    expect { JavaBuildpack::JreProperties.new('spec/fixtures/no_system_properties') }.to raise_error
  end

end
