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
require 'java_buildpack/system_properties'

module JavaBuildpack

  describe SystemProperties do

    it 'should raise an error if more than one system.properties file exists' do
      expect { SystemProperties.new('spec/fixtures/system_properties_multiple') }.to raise_error
    end

    it 'should populate instance with values from system.properties file if it exists' do
      system_properties = SystemProperties.new('spec/fixtures/system_properties_single')

      expect(system_properties['system.property']).to eq('system-property-value')
    end

    it 'should be an empty instance if system.properties file does not exist' do
      system_properties = SystemProperties.new('spec/fixtures/system_properties_none')

      expect(system_properties).to be_empty
    end

  end

end
