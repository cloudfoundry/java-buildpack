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
require 'logging_helper'
require 'java_buildpack/component/services'

describe JavaBuildpack::Component::Services do
  include_context 'with logging help'

  let(:services) { described_class.new('test' => service_payload) }

  context('when find_service') do

    context('with single service') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }]
      end

      it 'returns nil from find_service? if there is no service that matches' do
        expect(services.find_service('bad-test')).to be_nil
        expect(services.find_service(/bad-test/)).to be_nil
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_service('test-name')).to be(service_payload[0])
        expect(services.find_service(/test-name/)).to be(service_payload[0])
      end

      it 'returns service from find_service? if there is a matching label' do
        expect(services.find_service('test-label')).to be(service_payload[0])
        expect(services.find_service(/test-label/)).to be(service_payload[0])
      end

      it 'returns service from find_service? if there is a matching tag' do
        expect(services.find_service('test-tag')).to be(service_payload[0])
        expect(services.find_service(/test-tag/)).to be(service_payload[0])
      end

    end

    context('with two services') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan' },
         { 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }]
      end

      it 'returns nil from find_service? if there is no service that matches' do
        expect(services.find_service('bad-test')).to be_nil
        expect(services.find_service(/bad-test/)).to be_nil
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_service('test-name')).to be(service_payload[1])
        expect(services.find_service(/test-name/)).to be(service_payload[1])
      end

      it 'returns service from find_service? if there is a matching label' do
        expect(services.find_service('test-label')).to be(service_payload[1])
        expect(services.find_service(/test-label/)).to be(service_payload[1])
      end

      it 'returns service from find_service? if there is a matching tag' do
        expect(services.find_service('test-tag')).to be(service_payload[1])
        expect(services.find_service(/test-tag/)).to be(service_payload[1])
      end

    end

  end

  context('with find_volume_service') do

    context('with single service') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [{ 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                                 'device_type' => 'shared',
                                 'mode' => 'rw' }] }]
      end

      it 'returns nil from find_service? if there is no service that matches' do
        expect(services.find_volume_service('bad-test')).to be_nil
        expect(services.find_volume_service(/bad-test/)).to be_nil
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_volume_service('test-name')).to be(service_payload[0])
        expect(services.find_volume_service(/test-name/)).to be(service_payload[0])
      end

      it 'returns service from find_service? if there is a matching label' do
        expect(services.find_volume_service('test-label')).to be(service_payload[0])
        expect(services.find_volume_service(/test-label/)).to be(service_payload[0])
      end

      it 'returns service from find_service? if there is a matching tag' do
        expect(services.find_volume_service('test-tag')).to be(service_payload[0])
        expect(services.find_volume_service(/test-tag/)).to be(service_payload[0])
      end

    end

    context('with two services') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [] },
         { 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [{ 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                                 'device_type' => 'shared',
                                 'mode' => 'rw' }] }]
      end

      it 'returns nil from find_service? if there is no service that matches' do
        expect(services.find_volume_service('bad-test')).to be_nil
        expect(services.find_volume_service(/bad-test/)).to be_nil
      end

      it 'returns service from find_service? if there is a matching name' do
        expect(services.find_volume_service('test-name')).to be(service_payload[1])
        expect(services.find_volume_service(/test-name/)).to be(service_payload[1])
      end

      it 'returns service from find_service? if there is a matching label' do
        expect(services.find_volume_service('test-label')).to be(service_payload[1])
        expect(services.find_volume_service(/test-label/)).to be(service_payload[1])
      end

      it 'returns service from find_service? if there is a matching tag' do
        expect(services.find_volume_service('test-tag')).to be(service_payload[1])
        expect(services.find_volume_service(/test-tag/)).to be(service_payload[1])
      end

    end

  end

  context('with one_service') do

    context('with single service') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }]
      end

      it 'returns false from one_service? if there is no service that matches' do
        expect(services).not_to be_one_service('bad-test')
        expect(services).not_to be_one_service(/bad-test/)
      end

      it 'returns true from one_service? if there is a matching name' do
        expect(services).to be_one_service('test-name')
        expect(services).to be_one_service(/test-name/)
      end

      it 'returns true from one_service? if there is a matching label' do
        expect(services).to be_one_service('test-label')
        expect(services).to be_one_service(/test-label/)
      end

      it 'returns true from one_service? if there is a matching tag' do
        expect(services).to be_one_service('test-tag')
        expect(services).to be_one_service(/test-tag/)
      end

      it 'returns false from one_service? if there is a matching service without required credentials' do
        expect(services).not_to be_one_service('test-tag', 'bad-credential')
        expect(services).not_to be_one_service(/test-tag/, 'bad-credential')
      end

      it 'returns true from one_service? if there is a matching service with required credentials' do
        expect(services).to be_one_service('test-tag', 'uri')
        expect(services).to be_one_service(/test-tag/, 'uri')
      end

      it 'returns true from one_service? if there is a matching service with one required group credentials' do
        expect(services).to be_one_service('test-tag', %w[uri other])
        expect(services).to be_one_service(/test-tag/, %w[uri other])
      end

      it 'returns true from one_service? if there is a matching service with two required group credentials' do
        expect(services).to be_one_service('test-tag', %w[h1 h2])
        expect(services).to be_one_service(/test-tag/, %w[h1 h2])
      end

      it 'returns false from one_service? if there is a matching service with no required group credentials' do
        expect(services).not_to be_one_service('test-tag', %w[foo bar])
        expect(services).not_to be_one_service(/test-tag/, %w[foo bar])
      end

    end

    context('with two services') do

      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan' },
         { 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }]
      end

      it 'returns false from one_service? if there is no service that matches' do
        expect(services).not_to be_one_service('bad-test')
        expect(services).not_to be_one_service(/bad-test/)
      end

      it 'returns true from one_service? if there is a matching name' do
        expect(services).to be_one_service('test-name')
        expect(services).to be_one_service(/test-name/)
      end

      it 'returns true from one_service? if there is a matching label' do
        expect(services).to be_one_service('test-label')
        expect(services).to be_one_service(/test-label/)
      end

      it 'returns true from one_service? if there is a matching tag' do
        expect(services).to be_one_service('test-tag')
        expect(services).to be_one_service(/test-tag/)
      end

      it 'returns false from one_service? if there is a matching service without required credentials' do
        expect(services).not_to be_one_service('test-tag', 'bad-credential')
        expect(services).not_to be_one_service(/test-tag/, 'bad-credential')
      end

      it 'returns true from one_service? if there is a matching service with required credentials' do
        expect(services).to be_one_service('test-tag', 'uri')
        expect(services).to be_one_service(/test-tag/, 'uri')
      end

      it 'returns true from one_service? if there is a matching service with one required group credentials' do
        expect(services).to be_one_service('test-tag', %w[uri other])
        expect(services).to be_one_service(/test-tag/, %w[uri other])
      end

      it 'returns true from one_service? if there is a matching service with two required group credentials' do
        expect(services).to be_one_service('test-tag', %w[h1 h2])
        expect(services).to be_one_service(/test-tag/, %w[h1 h2])
      end

      it 'returns false from one_service? if there is a matching service with no required group credentials' do
        expect(services).not_to be_one_service('test-tag', %w[foo bar])
        expect(services).not_to be_one_service(/test-tag/, %w[foo bar])
      end

    end

  end

  context('with one_volume_service') do

    context('with no volume mounts') do
      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' } }]
      end

      it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-name')
        expect(services).not_to be_one_volume_service(/test-name/)
      end

      it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-label')
        expect(services).not_to be_one_volume_service(/test-label/)
      end

      it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-tag')
        expect(services).not_to be_one_volume_service(/test-tag/)
      end

    end

    context('with empty volume mounts') do
      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [] }]
      end

      it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-name')
        expect(services).not_to be_one_volume_service(/test-name/)
      end

      it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-label')
        expect(services).not_to be_one_volume_service(/test-label/)
      end

      it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-tag')
        expect(services).not_to be_one_volume_service(/test-tag/)
      end

    end

    context('with one volume mount') do
      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [{ 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                                 'device_type' => 'shared',
                                 'mode' => 'rw' }] }]
      end

      it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
        expect(services).to be_one_volume_service('test-name')
        expect(services).to be_one_volume_service(/test-name/)
      end

      it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
        expect(services).to be_one_volume_service('test-label')
        expect(services).to be_one_volume_service(/test-label/)
      end

      it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
        expect(services).to be_one_volume_service('test-tag')
        expect(services).to be_one_volume_service(/test-tag/)
      end

    end

    context('with two volume mounts') do
      let(:service_payload) do
        [{ 'name' => 'test-name', 'label' => 'test-label', 'tags' => ['test-tag'], 'plan' => 'test-plan',
           'credentials' => { 'uri' => 'test-uri', 'h1' => 'foo', 'h2' => 'foo' },
           'volume_mounts' => [{ 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                                 'device_type' => 'shared',
                                 'mode' => 'rw' },
                               { 'container_dir' => '/var/vcap/data/9ae0b817-1446-4915-9990-74c1bb26f147',
                                 'device_type' => 'shared',
                                 'mode' => 'rw' }] }]
      end

      it 'returns true from one_volume_service? if there is a matching name and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-name')
        expect(services).not_to be_one_volume_service(/test-name/)
      end

      it 'returns true from one_volume_service? if there is a matching label and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-label')
        expect(services).not_to be_one_volume_service(/test-label/)
      end

      it 'returns false from one_volume_service? if there is a matching tag and empty volume_mounts' do
        expect(services).not_to be_one_volume_service('test-tag')
        expect(services).not_to be_one_volume_service(/test-tag/)
      end

    end

  end

end
