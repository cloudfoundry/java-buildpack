# Encoding: utf-8

# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'java_buildpack/framework/contrast_security_agent'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Framework::ContrastSecurityAgent do
  include_context 'component_helper'
  let(:configuration) do
    { 'teamserver_url' => 'a_url',
      'org_uuid' => '12345',
      'username' => 'contrast_user',
      'api_key' => 'api_test',
      'service_key' => 'service_test' }
  end

  it 'does not detect without contrastsecurity service' do
    expect(component.detect).to be_nil
  end

  context do
    before do
      allow(services).to receive(:one_service?).with(/contrast[-]?security/,
                                                     'teamserver_url','username', 'api_key', 'service_key').and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => :configuration)
    end

    it 'detects with contrastsecurity service' do
      expect(component.detect).to eq("contrast-security-agent=#{version}")
    end

    it 'downloads Contrast Security agent JAR',
       cache_fixture: 'stub-contrast-security-agent.jar' do

      component.compile
      expect(sandbox + 'contrast-engine-0.0.0.jar').to exist
    end

    it 'updates JAVA_OPTS' do
      component.release

      expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/contrast_security_agent/contrast-engine-0.0.0.jar'\
        '=$PWD/.java-buildpack/contrast_security_agent/contrast.config')
      expect(java_opts).to include('-Dcontrast.dir=$TMPDIR')
      expect(java_opts).to include('-Dcontrast.override.appname=test-application-name')
    end

    it 'created contrast.config',
       cache_fixture: 'stub-contrast-security-agent.jar' do
      component.compile
      expect(sandbox + 'contrast.config').to exist
    end
  end

end
