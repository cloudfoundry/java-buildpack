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
require 'component_helper'
require 'java_buildpack/framework/spring_auto_reconfiguration'
require 'java_buildpack/framework/spring_auto_reconfiguration/web_xml_modifier'

describe JavaBuildpack::Framework::SpringAutoReconfiguration do
  include_context 'component_helper'

  it 'should detect with Spring JAR',
     app_fixture: 'framework_auto_reconfiguration_servlet_3' do

    expect(component.detect).to eq("spring-auto-reconfiguration=#{version}")
  end

  it 'should detect with Spring JAR which has a long name',
     app_fixture: 'framework_auto_reconfiguration_long_spring_jar_name' do

    expect(component.detect).to eq("spring-auto-reconfiguration=#{version}")
  end

  it 'should not detect without Spring JAR' do
    expect(component.detect).to be_nil
  end

  it 'should download additional libraries',
     app_fixture:   'framework_auto_reconfiguration_servlet_3',
     cache_fixture: 'stub-auto-reconfiguration.jar' do

    component.compile

    expect(sandbox + "spring_auto_reconfiguration-#{version}.jar").to exist
  end

  it 'should add to additional libraries',
     app_fixture:   'framework_auto_reconfiguration_servlet_3',
     cache_fixture: 'stub-auto-reconfiguration.jar' do

    component.release

    expect(additional_libraries).to include(sandbox + "spring_auto_reconfiguration-#{version}.jar")
  end

  context do

    let(:web_xml_modifier) { double('WebXmlModifier') }

    before do
      allow(JavaBuildpack::Framework::WebXmlModifier).to receive(:new).and_return(web_xml_modifier)
      expect(web_xml_modifier).to receive(:augment_root_context)
      expect(web_xml_modifier).to receive(:augment_servlet_contexts)
      allow(web_xml_modifier).to receive(:to_s).and_return('Test Content')
    end

    it 'should update web.xml if it exists',
       app_fixture:   'framework_auto_reconfiguration_servlet_2',
       cache_fixture: 'stub-auto-reconfiguration.jar' do

      component.compile

      expect((app_dir + 'WEB-INF/web.xml').read).to eq('Test Content')
    end

  end

end
