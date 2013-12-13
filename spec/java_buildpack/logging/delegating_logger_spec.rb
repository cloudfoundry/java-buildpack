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
require 'java_buildpack/logging/delegating_logger'
require 'logger'

describe JavaBuildpack::Logging::DelegatingLogger do

  let(:block) { ->() { 'test-message' } }
  let(:delegate1) { double('delegate1') }
  let(:delegate2) { double('delegate2') }
  let(:delegating_logger) { described_class.new('test-klass', [delegate1, delegate2]) }

  it 'should delegate FATAL calls' do
    expect(delegate1).to receive(:add).with(Logger::FATAL, nil, 'test-klass')
    expect(delegate2).to receive(:add).with(Logger::FATAL, nil, 'test-klass')

    delegating_logger.fatal
  end

  it 'should delegate ERROR calls' do
    expect(delegate1).to receive(:add).with(Logger::ERROR, nil, 'test-klass')
    expect(delegate2).to receive(:add).with(Logger::ERROR, nil, 'test-klass')

    delegating_logger.error
  end

  it 'should delegate WARN calls' do
    expect(delegate1).to receive(:add).with(Logger::WARN, nil, 'test-klass')
    expect(delegate2).to receive(:add).with(Logger::WARN, nil, 'test-klass')

    delegating_logger.warn
  end

  it 'should delegate INFO calls' do
    expect(delegate1).to receive(:add).with(Logger::INFO, nil, 'test-klass')
    expect(delegate2).to receive(:add).with(Logger::INFO, nil, 'test-klass')

    delegating_logger.info
  end

  it 'should delegate DEBUG calls' do
    expect(delegate1).to receive(:add).with(Logger::DEBUG, nil, 'test-klass')
    expect(delegate2).to receive(:add).with(Logger::DEBUG, nil, 'test-klass')

    delegating_logger.debug
  end

end
