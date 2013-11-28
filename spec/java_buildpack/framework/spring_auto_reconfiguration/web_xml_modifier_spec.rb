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
require 'java_buildpack/framework/spring_auto_reconfiguration/web_xml_modifier'

describe JavaBuildpack::Framework::WebXmlModifier do

  it 'should not modify root if there is no ContextLoaderListener' do
    assert_equality('web_root_no_contextLoaderListener') do |modifier|
      modifier.augment_root_context
    end
  end

  it 'should not modify a servlet if is not a DispatcherServlet' do
    assert_equality('web_servlet_no_DispatcherServlet') do |modifier|
      modifier.augment_root_context
    end
  end

  it 'should add a new contextConfigLocation and contextInitializerClasses if they do not exist' do
    assert_equality('web_root_no_params') do |modifier|
      modifier.augment_root_context
    end

    assert_equality('web_servlet_no_params') do |modifier|
      modifier.augment_servlet_contexts
    end
  end

  it 'should update existing contextConfigLocation and contextInitializerClasses if they do exist' do
    assert_equality('web_root_existing_params') do |modifier|
      modifier.augment_root_context
    end

    assert_equality('web_servlet_existing_params') do |modifier|
      modifier.augment_servlet_contexts
    end
  end

  it 'should use annotation-based contextConfigLocation if contextClass is annotation-based' do
    assert_equality('web_root_annotation') do |modifier|
      modifier.augment_root_context
    end

    assert_equality('web_servlet_annotation') do |modifier|
      modifier.augment_servlet_contexts
    end
  end

  it 'should ignore contextClass with wrong value' do
    assert_equality('web_root_annotation_wrong_class') do |modifier|
      modifier.augment_root_context
    end
  end

  def assert_equality(fixture)
    modifier = described_class.new(Pathname.new("spec/fixtures/#{fixture}_before.xml").read)

    yield modifier

    actual = modifier.to_s
    expected = Pathname.new("spec/fixtures/#{fixture}_after.xml").read

    expect(actual).to eq(expected)
  end

end
