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

describe JavaBuildpack::SelectedJre do

  it 'should read properties from system.properties' do
    selected_jre = JavaBuildpack::SelectedJre.new('spec/fixtures/single_system_properties')

    expect(selected_jre.id).to eq('java-openjdk-8')
    expect(selected_jre.type).to eq(JavaBuildpack::SelectedJre::JRES['openjdk']['8'][:type])
    expect(selected_jre.uri).to eq(JavaBuildpack::SelectedJre::JRES['openjdk']['8'][:uri])
    expect(selected_jre.vendor).to eq('openjdk')
    expect(selected_jre.version).to eq('8')
  end

  it 'should read properties from environment variables' do
    previous_vendor = nil
    previous_version = nil
    begin
      previous_vendor = ENV['JAVA_RUNTIME_VENDOR']
      ENV['JAVA_RUNTIME_VENDOR'] = 'oracle'
      previous_version = ENV['JAVA_RUNTIME_VERSION']
      ENV['JAVA_RUNTIME_VERSION'] = '1.7'

      selected_jre = JavaBuildpack::SelectedJre.new('spec/fixtures/single_system_properties')

      expect(selected_jre.id).to eq('java-oracle-7')
      expect(selected_jre.type).to eq(JavaBuildpack::SelectedJre::JRES['oracle']['7'][:type])
      expect(selected_jre.uri).to eq(JavaBuildpack::SelectedJre::JRES['oracle']['7'][:uri])
      expect(selected_jre.vendor).to eq('oracle')
      expect(selected_jre.version).to eq('7')
    ensure
      ENV['JAVA_RUNTIME_VENDOR'] = previous_vendor
      ENV['JAVA_RUNTIME_VERSION'] = previous_version
    end
  end

  it 'should raise an error if there are multiple system.properties' do
    expect { JavaBuildpack::SelectedJre.new('spec/fixtures/multiple_system_properties') }.to raise_error
  end

  it 'should raise an error if an error invalid vendor or version is specified' do
    expect { JavaBuildpack::SelectedJre.new('spec/fixtures/invalid_vendor') }.to raise_error("'sun' is not a valid Java runtime vendor")
    expect { JavaBuildpack::SelectedJre.new('spec/fixtures/invalid_version') }.to raise_error("'5' is not a valid Java runtime version")
  end

end
