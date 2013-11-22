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
require 'java_buildpack/util/service_utils'

module JavaBuildpack::Util

  describe ServiceUtils do

    let(:vcap_services) do
      {
          'newrelic-n/a' => [{ 'name' => 'new-relic' }],
          'elephantsql-n/a' => [{ 'name' => 'db1' }, { 'name' => 'db2' }]
      }
    end

    let(:vcap_services_with_name) do
      {
          'name-n/a' => [{ 'name' => 'xnewrelicx' }]
      }
    end

    let(:vcap_services_with_label) do
      {
          'name-n/a' => [{ 'label' => 'xnewrelicx' }]
      }
    end

    let(:vcap_services_with_tags) do
      {
          'name-n/a' => [{ 'tags' => %w(y xnewrelicx z) }]
      }
    end

    let(:vcap_services_with_plan) do
      {
          'name-n/a' => [{ 'plan' => 'xnewrelicx' }]
      }
    end

    it 'should return nil if no service matches' do
      expect(ServiceUtils.find_service(vcap_services, /alpha/)).to be_nil
    end

    it 'should raise an error if more than one service type matches' do
      expect { ServiceUtils.find_service(vcap_services, /e/) }
      .to raise_error /Exactly one service type matching 'e' can be bound.  Found 2./
    end

    it 'should raise an error if more than one service instance matches' do
      expect { ServiceUtils.find_service(vcap_services, /elephant/) }
      .to raise_error /Exactly one service instance matching 'elephant' can be bound.  Found 2./
    end

    it 'should return the contents of the service if matched' do
      expect(ServiceUtils.find_service(vcap_services, /newrelic/)).to eq(vcap_services['newrelic-n/a'][0])
    end

    it 'should return the contents of the service if name matched' do
      expect(ServiceUtils.find_service(vcap_services_with_name, /newrelic/))
      .to eq(vcap_services_with_name['name-n/a'][0])
    end

    it 'should return the contents of the service if label matched' do
      expect(ServiceUtils.find_service(vcap_services_with_label, /newrelic/))
      .to eq(vcap_services_with_label['name-n/a'][0])
    end

    it 'should return the contents of the service if a tag matched' do
      expect(ServiceUtils.find_service(vcap_services_with_tags, /newrelic/))
      .to eq(vcap_services_with_tags['name-n/a'][0])
    end

    it 'should return nil if plan would have matched' do
      expect(ServiceUtils.find_service(vcap_services_with_plan, /newrelic/))
      .to be_nil
    end

  end

end
