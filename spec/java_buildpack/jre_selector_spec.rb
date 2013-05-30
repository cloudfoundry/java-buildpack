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

describe JavaBuildpack::JreSelector do

  it 'should return a URI for a known vendor and a known version' do
    jre_selector = JavaBuildpack::JreSelector.new

    expect(jre_selector.uri('openjdk', '1.8')).to eq(JavaBuildpack::JreSelector::JRES['openjdk']['8'][:uri])
  end

  it 'should return a URI for a known vendor and a marketing version' do
    jre_selector = JavaBuildpack::JreSelector.new

    expect(jre_selector.uri('openjdk', '8')).to eq(JavaBuildpack::JreSelector::JRES['openjdk']['8'][:uri])
  end

  it 'should raise an error if the vendor is unknown' do
    expect { JavaBuildpack::JreSelector.new.uri('novendor', '8') }.to raise_error
  end

  it 'should raise an error if the version is unknown' do
    expect { JavaBuildpack::JreSelector.new.uri('openjdk', '5') }.to raise_error
  end
end
