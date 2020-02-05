# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/logging/delegating_logger'
require 'logger'

describe JavaBuildpack::Logging::DelegatingLogger do

  let(:block) { -> { 'test-message' } }
  let(:delegate1) { instance_double('delegate1') }
  let(:delegate2) { instance_double('delegate2') }
  let(:delegating_logger) { described_class.new('test-klass', [delegate1, delegate2]) }

  it 'delegates FATAL calls' do
    allow(delegate1).to receive(:add).with(Logger::FATAL, nil, 'test-klass')
    allow(delegate2).to receive(:add).with(Logger::FATAL, nil, 'test-klass')

    delegating_logger.fatal
  end

  it 'delegates ERROR calls' do
    allow(delegate1).to receive(:add).with(Logger::ERROR, nil, 'test-klass')
    allow(delegate2).to receive(:add).with(Logger::ERROR, nil, 'test-klass')

    delegating_logger.error
  end

  it 'delegates WARN calls' do
    allow(delegate1).to receive(:add).with(Logger::WARN, nil, 'test-klass')
    allow(delegate2).to receive(:add).with(Logger::WARN, nil, 'test-klass')

    delegating_logger.warn
  end

  it 'delegates INFO calls' do
    allow(delegate1).to receive(:add).with(Logger::INFO, nil, 'test-klass')
    allow(delegate2).to receive(:add).with(Logger::INFO, nil, 'test-klass')

    delegating_logger.info
  end

  it 'delegates DEBUG calls' do
    allow(delegate1).to receive(:add).with(Logger::DEBUG, nil, 'test-klass')
    allow(delegate2).to receive(:add).with(Logger::DEBUG, nil, 'test-klass')

    delegating_logger.debug
  end

end
