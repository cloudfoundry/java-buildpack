# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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
require 'component_helper'
require 'java_buildpack/coprocess/jaeger_agent'
require 'pathname'

describe JavaBuildpack::Coprocess::JaegerAgent do
  include_context 'with component help'

  it 'does not detect without jaeger-n/a service' do
    expect(component.detect).to be_nil
  end

  context do
    before do
      allow(services).to receive(:one_service?).with(/jaeger/, 'jaeger-collector-url', 'tls_ca', 'tls_cert', 'tls_key')
                                               .and_return(true)
      allow(services).to receive(:find_service)
        .and_return('credentials' => { 'jaeger-collector-url' => 'test-collector',
                                       'tls_ca' => 'abc',
                                       'tls_cert' => 'abc',
                                       'tls_key' => 'abc' })
      allow(application_cache).to receive(:get)
        .and_yield(Pathname.new('spec/fixtures/stub-jaeger-agent.tar.gz').open, false)
    end

    it 'detects with jaeger-n/a service' do
      expect(component.detect).to match('jaeger-agent=')
    end

    it 'expands jaeger binaries and verifies the files are created',
       cache_fixture: 'stub-jaeger-agent.tar.gz' do

      component.compile

      expect(droplet.root + 'jaeger/jaeger-agent').to exist
      expect(droplet.root + 'jaeger/ca_cert.crt').to exist
      expect(droplet.root + 'jaeger/tls_cert.crt').to exist
      expect(droplet.root + 'jaeger/tls_key.key').to exist
    end

    it 'verifies the release string' do
      expected_string =
        [
          '($PWD/jaeger/jaeger-agent',
          '--reporter.grpc.tls=true',
          '--reporter.grpc.tls.ca=$PWD/jaeger/ca_cert.crt',
          '--reporter.grpc.tls.cert=$PWD/jaeger/tls_cert.crt',
          '--reporter.grpc.tls.key=$PWD/jaeger/tls_key.key',
          '--reporter.grpc.host-port=test-collector',
          '&)'
        ].flatten.compact.join(' ')
      expect(component.release).to eq expected_string
    end

    it 'verifies the release string with additional parameter' do
      ENV['JAEGER_ADDITIONAL_ARGUEMENTS'] = '--reporter.grpc.retry.max=3'

      expected_string =
        [
          '($PWD/jaeger/jaeger-agent',
          '--reporter.grpc.tls=true',
          '--reporter.grpc.tls.ca=$PWD/jaeger/ca_cert.crt',
          '--reporter.grpc.tls.cert=$PWD/jaeger/tls_cert.crt',
          '--reporter.grpc.tls.key=$PWD/jaeger/tls_key.key',
          '--reporter.grpc.host-port=test-collector',
          '--reporter.grpc.retry.max=3',
          '&)'
        ].flatten.compact.join(' ')
      expect(component.release).to eq expected_string
    end

  end

end
