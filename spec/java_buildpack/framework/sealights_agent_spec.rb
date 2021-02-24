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
require 'component_helper'
require 'java_buildpack/framework/sealights_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::SealightsAgent do
  include_context 'with component help'

  let(:configuration) do
    { 'buildSessionId' => '1234',
      'buildSessionIdFile' => 'buildSessionId.txt',
      'proxy' => '127.0.0.1:8888'}
  end

  it 'does not detect without sealights service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/Sealights/, 'token').and_return(true)
    end

    it 'detects with sealights service' do
      expect(component.detect).to eq("sealights-agent=latest")
    end

    # eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL1BST0QtU1RBR0lORy5hdXRoLnNlYWxpZ2h0cy5pby8iLCJqd3RpZCI6IlBST0QtU1RBR0lORyxpLTAxM2EyZTU1N2YzOWUzMzNkLEFQSUdXLTE2NGE0NTJkLTY1ZTktNGY4ZC1iODVkLWRjNWJlNGJhZDM2NSwxNDg2MDQ0MjI1NDQ2Iiwic3ViamVjdCI6IlNlYUxpZ2h0c0BhZ2VudCIsImF1ZGllbmNlIjpbImFnZW50cyJdLCJ4LXNsLXJvbGUiOiJhZ2VudCIsIngtc2wtc2VydmVyIjoiaHR0cHM6Ly9QUk9ELVNUQUdJTkctZ3cuc2VhbGlnaHRzLmNvL2FwaSIsInNsX2ltcGVyX3N1YmplY3QiOiIiLCJpYXQiOjE0ODYwNDQyMjV9.O5YrJTiwCj7Nd_5A9-3TGz1Rv_MEj47S6QRpTkfGRwokOiMNh15XybiZ_yOmhbEUYSmNFos84tIlPyrQbySqI7XrksgSWxbM-bysbnXRwzMAf-z4jcRI5xa-YjhNS5VJ01-CynJrBgCl7htZ5BuyPVCbeEgCWWAsJtApIPlYZCRwGo7DEVc7MZbfBa5Qd0S7RzCukuVX6J-mWWM3Fan6zKAOqCKWRqsDNvzi3kTLAH_7-ps1MzQLGFhUE6fR-5Z1P1DRFdoi6uHhg-DA2Qo_9alH6Aa78GadR0MnSMLieeMUZxn13zFCjwlVgprkJkkbMZUdEOCVulDe-CKSDWH3bsUhq93gxR1D-WjwT28e9CIYV7BycQqFmAunrXOdBfwQTFQ2YjjVRxdZduqgTaeSdlLC7ZhRScII5K2exseu-YvAd7JHMEyTKIXrz6yDLk-V1kQ1her1o9sqSe9zjIEDXeLxvJhdeo8sfG48fIr4BaFXBvKhUv8Mu6IHvHT10FDZfqR9SuQsGQ8biSMEf-7a7X7tE02pSgjOjYytis3EFc5c4ArEyLRsfNWXNN4FqUh5njon4SYEOZzlIaGu0zdrPuEK0aD4bxvS2cztHHvkBk5E5KTFxGVx8iA-ho8P5EfRrTHYylr7HWvApf3BmaahQjAfv-qt_NxGQvMshdE-D8U

    it 'updates JAVA_OPTS' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'token' => 'fake_token' })

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/sealights_agent/sl-test-listener.jar' )
    end

    it 'updates JAVA_OPTS with additional options' do
      allow(services).to receive(:find_service).and_return('credentials' => { 'token' => 'fake_token'})

      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/sealights_agent/sl-test-listener.jar' )
      expect(java_opts).to include('-Dsl.buildSessionId=1234')
      expect(java_opts).to include('-Dsl.buildSessionIdFile=buildSessionId.txt')
      expect(java_opts).to include('-Dsl.proxy=127.0.0.1:8888')
    end

  end

end
