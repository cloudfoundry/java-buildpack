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
    expect(described_class.use_internet?).to be
  end

  it 'should not have stored internet availability by default' do
    expect(described_class.internet_availability_stored?).not_to be
  end

  it 'should not use internet if remote downloads are disabled' do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('cache')
                                                      .and_return('remote_downloads' => 'disabled')

    expect(described_class.use_internet?).not_to be
    expect(described_class.internet_availability_stored?).to be
  end

  it 'should raise error if remote downloads are wrongly configured' do
    allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('cache').and_return('remote_downloads' => 'x')

    expect { described_class.use_internet? }.to raise_error /Invalid remote_downloads configuration/
  end

  it 'should record availability of the internet' do
    described_class.internet_available
    expect(described_class.internet_availability_stored?).to be
    expect(described_class.use_internet?).to be
  end

  it 'should record unavailability of the internet but not log the first time' do
    described_class.internet_unavailable('test reason')
    expect(described_class.internet_availability_stored?).to be
    expect(described_class.use_internet?).not_to be
    expect(log_contents).not_to match /test reason/
  end

  it 'should record unavailability of the internet and log after the first time' do
    described_class.internet_unavailable('test reason')
    described_class.internet_unavailable('another reason')
    expect(log_contents).to match /another reason/
  end

end
