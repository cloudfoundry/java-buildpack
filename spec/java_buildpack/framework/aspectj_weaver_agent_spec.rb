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
require 'java_buildpack/framework/aspectj_weaver_agent'

describe JavaBuildpack::Framework::AspectjWeaverAgent do
  include_context 'with component help'

  it 'does not detect if not enabled' do
    expect(component.detect).to be_nil
  end

  context do
    let(:configuration) { { 'enabled' => true } }

    it 'does not detect if aop.xml only',
       app_fixture: 'framework_aspectj_weaver_aop_xml_only' do

      expect(component.detect).to be_nil
    end

    it 'detects when aop.xml in BOOT-INF classes',
       app_fixture: 'framework_aspectj_weaver_boot_inf_classes' do

      expect(component.detect).to eq('aspectj-weaver-agent=1.8.10')
    end

    it 'detects when aop.xml in BOOT-INF/classes/META-INF',
       app_fixture: 'framework_aspectj_weaver_boot_inf_classes_meta_inf' do

      expect(component.detect).to eq('aspectj-weaver-agent=1.8.10')
    end

    it 'does not detect if JAR only',
       app_fixture: 'framework_aspectj_weaver_jar_only' do

      expect(component.detect).to be_nil
    end

    it 'detects when aop.xml in META-INF',
       app_fixture: 'framework_aspectj_weaver_meta_inf' do

      expect(component.detect).to eq('aspectj-weaver-agent=1.8.10')
    end

    it 'detects when aop.xml in classes',
       app_fixture: 'framework_aspectj_weaver_classes' do

      expect(component.detect).to eq('aspectj-weaver-agent=1.8.10')
    end

    it 'adds java agent',
       app_fixture: 'framework_aspectj_weaver_boot_inf_classes' do

      component.release
      expect(java_opts).to include('-javaagent:$PWD/BOOT-INF/lib/aspectjweaver-1.8.10.jar')
    end
  end

end
