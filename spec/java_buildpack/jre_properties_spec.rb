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

  it 'should read properties from system.properties' do
    selected_jre = JavaBuildpack::JreProperties.new('spec/fixtures/single_system_properties')

    expect(selected_jre.vendor).to eq('openjdk')
    expect(selected_jre.version).to eq('8')
  end

  it 'should read properties from environment variables in preference to system.properties' do
    previous_vendor = nil
    previous_version = nil
    begin
      previous_vendor = ENV['JAVA_RUNTIME_VENDOR']
      ENV['JAVA_RUNTIME_VENDOR'] = 'somevendor'
      previous_version = ENV['JAVA_RUNTIME_VERSION']
      ENV['JAVA_RUNTIME_VERSION'] = '1.7'

      jre_properties = JavaBuildpack::JreProperties.new('spec/fixtures/single_system_properties')

      expect(jre_properties.vendor).to eq('somevendor')
      expect(jre_properties.version).to eq('1.7')
    ensure
      ENV['JAVA_RUNTIME_VENDOR'] = previous_vendor
      ENV['JAVA_RUNTIME_VERSION'] = previous_version
    end
  end

  it 'should raise an error if there are multiple system.properties' do
    expect { JavaBuildpack::JreProperties.new('spec/fixtures/multiple_system_properties') }.to raise_error
  end

  it 'should default the vendor if there is no system.properties and no vendor environment variable is set' do
    previous_vendor = nil
    begin
      previous_vendor = ENV['JAVA_RUNTIME_VENDOR']
      ENV['JAVA_RUNTIME_VENDOR'] = nil
      jre_properties = JavaBuildpack::JreProperties.new('spec/fixtures/no_system_properties')
      expect(jre_properties.vendor).to eq(JavaBuildpack::JreProperties::DEFAULT_VENDOR)
    ensure
      ENV['JAVA_RUNTIME_VENDOR'] = previous_vendor
    end

  end
end
