# Cloud Foundry Java Buildpack Utilities
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

  before do
    @selected_jre = described_class.new('spec/fixtures/java')
  end

  it 'should return the id' do
    expect(@selected_jre.id).to eq('java-openjdk-8')
  end

  it 'should return the uri' do
    expect(@selected_jre.uri).to eq(JavaBuildpack::SelectedJre::JRES[:openjdk][:J8])
  end

end
