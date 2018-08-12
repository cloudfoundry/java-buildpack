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
require 'java_buildpack/framework/snyk'

describe JavaBuildpack::Framework::Snyk do
  include_context 'with component help'

  it 'does not detect without snyk service' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).and_return(true)

      allow(services).to receive(:find_service)
        .and_return(
          'credentials' => {
            'apiToken' => '01234567-8901-2345-6789-012345678901',
            'apiUrl' => 'https://my.internal.snyk/api',
            'orgName' => 'my-org'
          }
        )
    end

    it 'detects with snyk service' do
      expect(component.detect).to eq('snyk')
    end

  end

  it 'returns succesfully before query if no manifests found' do
    stub = stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
    component.compile
    expect(stub).not_to have_been_requested
  end

  context do

    let(:environment) { super().merge 'SNYK_TOKEN' => 'some-token' }

    SNYK_DEFAULT_API = 'https://snyk.io/api'
    SNYK_REQUEST_WITH_POMS = {
      headers: { 'Content-Type' => 'application/json', 'Authorization' => 'token some-token' },
      body: {
        "encoding": 'plain',
        "files": {
          "target": { "contents": File.read('spec/fixtures/snyk_fixture_fs_pom.xml') },
          "additional": [{ "contents": File.read('spec/fixtures/snyk_fixture_jar_pom.xml') }]
        }
      }
    }.freeze
    SNYK_RESPONSE_ISSUES = File.read('spec/fixtures/snyk_response_issues.json')
    SNYK_RESPONSE_NO_ISSUES = File.read('spec/fixtures/snyk_response_no_issues.json')

    it 'return sucessfully if no issues found',
       app_fixture: 'framework_snyk_app' do

      stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
        .with(SNYK_REQUEST_WITH_POMS)
        .to_return(status: 200, body: SNYK_RESPONSE_NO_ISSUES)

      expect { component.compile }.not_to raise_error
    end

    it 'print error message of api error',
       app_fixture: 'framework_snyk_app' do

      UNAUTHORIZED = '{"code":401,"message":"Not authorised","error":"Not authorised"}'
      stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
        .with(SNYK_REQUEST_WITH_POMS)
        .to_return(status: 401, body: UNAUTHORIZED)

      expect { component.compile }.to raise_error(/Api error: Not authorised/)
    end

    it 'print snyk support email if account lacks entitlement',
       app_fixture: 'framework_snyk_app' do

      NOT_ENTITILED = '{ "error": true, "message": "The org myOrg (3e016388-7661-477d-8c3a-f7be0d6557a9) is not ' \
                      'entitled for api access. Please upgrade your plan to access this capability"}'

      stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
        .with(SNYK_REQUEST_WITH_POMS)
        .to_return(status: 403, body: NOT_ENTITILED)

      expect { component.compile }.to raise_error(/.*upgrade your plan.*\(please contact us at support@snyk\.io\).*/)
    end

    context do
      another_api = 'https://another.snyk.com/api'
      let(:environment) { super().merge 'SNYK_API' => another_api }

      it 'queries another api endpoint if present',
         app_fixture: 'framework_snyk_app' do

        another_api = 'https://another.snyk.com/api'
        stub = stub_request(:post, "#{another_api}/v1/test/maven")
               .with(SNYK_REQUEST_WITH_POMS)
               .to_return(body: SNYK_RESPONSE_NO_ISSUES)

        component.compile
        expect(stub).to have_been_requested
      end
    end

    context do
      org_name = 'someOrganization'
      let(:environment) { super().merge 'SNYK_ORG_NAME' => org_name }

      it 'takes into consideration organization param',
         app_fixture: 'framework_snyk_app' do

        stub = stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
               .with(SNYK_REQUEST_WITH_POMS)
               .with(query: { 'org' => org_name })
               .to_return(body: SNYK_RESPONSE_NO_ISSUES)

        component.compile
        expect(stub).to have_been_requested
      end
    end

    it 'raises error if issues were found',
       app_fixture: 'framework_snyk_app' do

      stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
        .with(SNYK_REQUEST_WITH_POMS)
        .to_return(body: SNYK_RESPONSE_ISSUES)

      expect { component.compile }.to raise_error(/Snyk found vulnerabilities/)
    end

    context do
      let(:environment) { super().merge 'SNYK_DONT_BREAK_BUILD' => 'true' }

      it 'return succesfully if issues were found but dont_break_build is true',
         app_fixture: 'framework_snyk_app' do

        stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
          .with(SNYK_REQUEST_WITH_POMS)
          .to_return(body: SNYK_RESPONSE_ISSUES)

        expect { component.compile }.not_to raise_error
      end
    end

    context do
      let(:environment) { super().merge 'SNYK_SEVERITY_THRESHOLD' => 'high' }

      it 'return succesfully if issues were found but none above threshold',
         app_fixture: 'framework_snyk_app' do

        stub_request(:post, SNYK_DEFAULT_API + '/v1/test/maven')
          .with(SNYK_REQUEST_WITH_POMS)
          .to_return(body: SNYK_RESPONSE_ISSUES)

        expect { component.compile }.not_to raise_error
      end
    end
  end
end
