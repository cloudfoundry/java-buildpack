# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'internet_availability_helper'
require 'logging_helper'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/cache/internet_availability'

describe JavaBuildpack::Util::Cache::InternetAvailability do
  include_context 'internet_availability_helper'
  include_context 'logging_helper'

  it 'should use internet by default' do
    expect(described_class.instance.available?).to be
  end

  context do

    before do
      allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('cache')
                                                        .and_return('remote_downloads' => 'disabled')
      described_class.instance.send :initialize
    end

    it 'should not use internet if remote downloads are disabled' do
      expect(described_class.instance.available?).not_to be
    end
  end

  it 'should record availability' do
    described_class.instance.available false

    expect(described_class.instance.available?).not_to be
    expect(log_contents).not_to match(/Internet availability set to false/)
  end

  it 'should record availability with message' do
    described_class.instance.available false, 'test message'

    expect(described_class.instance.available?).not_to be
    expect(log_contents).to match(/Internet availability set to false: test message/)
  end

  it 'should temporarily set internet unavailable' do
    expect(described_class.instance.available?).to be

    described_class.instance.available(false) { expect(described_class.instance.available?).not_to be }

    expect(described_class.instance.available?).to be
  end

  it 'should temporarily set internet available',
     :disable_internet do

    expect(described_class.instance.available?).not_to be

    described_class.instance.available(true) { expect(described_class.instance.available?).to be }

    expect(described_class.instance.available?).not_to be
  end

end
