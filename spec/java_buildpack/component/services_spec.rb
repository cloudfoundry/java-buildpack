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
require 'java_buildpack/component/services'

describe JavaBuildpack::Component::Services do

  let(:service) do
    { 'name'        => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
      'credentials' => { 'uri' => 'test-uri' } }
  end

  let(:services) { described_class.new('test' => [service]) }

  it 'should return false from one_service? if there is no service that matches' do
    expect(services.one_service? 'bad-test').not_to be
    expect(services.one_service? /bad-test/).not_to be
  end

  it 'should return true from one_service? if there is a matching name' do
    expect(services.one_service? 'test-name').to be
    expect(services.one_service? /test-name/).to be
  end

  it 'should return true from one_service? if there is a matching label' do
    expect(services.one_service? 'test-label').to be
    expect(services.one_service? /test-label/).to be
  end

  it 'should return true from one_service? if there is a matching tag' do
    expect(services.one_service? 'test-tag').to be
    expect(services.one_service? /test-tag/).to be
  end

  it 'should return nil from find_service? if there is no service that matches' do
    expect(services.find_service 'bad-test').to be_nil
    expect(services.find_service /bad-test/).to be_nil
  end

  it 'should return true from one_service? if there is a matching name' do
    expect(services.find_service 'test-name').to be(service)
    expect(services.find_service /test-name/).to be(service)
  end

  it 'should return true from one_service? if there is a matching label' do
    expect(services.find_service 'test-label').to be(service)
    expect(services.find_service /test-label/).to be(service)
  end

  it 'should return true from one_service? if there is a matching tag' do
    expect(services.find_service 'test-tag').to be(service)
    expect(services.find_service /test-tag/).to be(service)
  end

end
