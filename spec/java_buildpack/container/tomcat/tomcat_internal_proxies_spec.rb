# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/container/tomcat/tomcat_internal_proxies'

describe JavaBuildpack::Container::TomcatInternalProxies do
  include_context 'with component help'

  let(:component_id) { 'tomcat' }

  context 'when no internal proxies regex is specified' do

    it 'does not mutate server.xml',
       app_fixture: 'container_tomcat_internal_proxies' do
      component.compile

      expect((sandbox + 'conf/server.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_internal_proxies_server_unmodified.xml').read)
    end

  end

  context 'when internal proxies regex is specified' do

    let(:configuration) do
      { 'regex' => '1.2.3.4' }
    end

    it 'mutates server.xml',
       app_fixture: 'container_tomcat_internal_proxies' do
      component.compile

      expect((sandbox + 'conf/server.xml').read)
        .to eq(Pathname.new('spec/fixtures/container_tomcat_internal_proxies_server_after.xml').read)
    end

  end

end
