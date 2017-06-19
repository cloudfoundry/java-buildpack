# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'logging_helper'
require 'java_buildpack/component/services'

describe JavaBuildpack::Component::Services do
  include_context 'logging_helper'

  let(:service) do
    { 'name'        => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
      'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }
  end

  let(:services) { described_class.new('test' => [service]) }

  it 'returns false from one_service? if there is no service that matches' do
    expect(services.one_service?('bad-test')).not_to be
    expect(services.one_service?(/bad-test/)).not_to be
  end

  it 'returns true from one_service? if there is a matching name' do
    expect(services.one_service?('test-name')).to be
    expect(services.one_service?(/test-name/)).to be
  end

  it 'returns true from one_service? if there is a matching label' do
    expect(services.one_service?('test-label')).to be
    expect(services.one_service?(/test-label/)).to be
  end

  it 'returns true from one_service? if there is a matching tag' do
    expect(services.one_service?('test-tag')).to be
    expect(services.one_service?(/test-tag/)).to be
  end

  it 'returns false from one_service? if there is a matching service without required credentials' do
    expect(services.one_service?('test-tag', 'bad-credential')).not_to be
    expect(services.one_service?(/test-tag/, 'bad-credential')).not_to be
  end

  it 'returns true from one_service? if there is a matching service with required credentials' do
    expect(services.one_service?('test-tag', 'uri')).to be
    expect(services.one_service?(/test-tag/, 'uri')).to be
  end

  it 'returns true from one_service? if there is a matching service with one required group credentials' do
    expect(services.one_service?('test-tag', %w[uri other])).to be
    expect(services.one_service?(/test-tag/, %w[uri other])).to be
  end

  it 'returns true from one_service? if there is a matching service with two required group credentials' do
    expect(services.one_service?('test-tag', %w[h1 h2])).to be
    expect(services.one_service?(/test-tag/, %w[h1 h2])).to be
  end

  it 'returns false from one_service? if there is a matching service with no required group credentials' do
    expect(services.one_service?('test-tag', %w[foo bar])).not_to be
    expect(services.one_service?(/test-tag/, %w[foo bar])).not_to be
  end

  it 'returns true from one_volume_service? if there is a matching name and no volume_mounts' do
    expect(services.one_volume_service?('test-name')).not_to be
    expect(services.one_volume_service?(/test-name/)).not_to be
  end

  it 'returns true from one_volume_service? if there is a matching label and no volume_mounts' do
    expect(services.one_volume_service?('test-label')).not_to be
    expect(services.one_volume_service?(/test-label/)).not_to be
  end

  it 'returns false from one_volume_service? if there is a matching tag and no volume_mounts' do
    expect(services.one_volume_service?('test-tag')).not_to be
    expect(services.one_volume_service?(/test-tag/)).not_to be
  end

  context do
    let(:service) do
      { 'name'          => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
        'credentials'   => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
        'volume_mounts' => [] }
    end

    it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
      expect(services.one_volume_service?('test-name')).not_to be
      expect(services.one_volume_service?(/test-name/)).not_to be
    end

    it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
      expect(services.one_volume_service?('test-label')).not_to be
      expect(services.one_volume_service?(/test-label/)).not_to be
    end

    it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
      expect(services.one_volume_service?('test-tag')).not_to be
      expect(services.one_volume_service?(/test-tag/)).not_to be
    end

  end

  context do
    let(:service) do
      { 'name'          => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
        'credentials'   => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
        'volume_mounts' => [{ 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                              'device_type'   => 'shared',
                              'mode'          => 'rw' }] }
    end

    it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
      expect(services.one_volume_service?('test-name')).to be
      expect(services.one_volume_service?(/test-name/)).to be
    end

    it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
      expect(services.one_volume_service?('test-label')).to be
      expect(services.one_volume_service?(/test-label/)).to be
    end

    it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
      expect(services.one_volume_service?('test-tag')).to be
      expect(services.one_volume_service?(/test-tag/)).to be
    end

  end

  it 'returns nil from find_service? if there is no service that matches' do
    expect(services.find_service('bad-test')).to be_nil
    expect(services.find_service(/bad-test/)).to be_nil
  end

  it 'returns service from find_service? if there is a matching name' do
    expect(services.find_service('test-name')).to be(service)
    expect(services.find_service(/test-name/)).to be(service)
  end

  it 'returns service from find_service? if there is a matching label' do
    expect(services.find_service('test-label')).to be(service)
    expect(services.find_service(/test-label/)).to be(service)
  end

  it 'returns service from find_service? if there is a matching tag' do
    expect(services.find_service('test-tag')).to be(service)
    expect(services.find_service(/test-tag/)).to be(service)
  end

end
