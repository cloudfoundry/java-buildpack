# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

  it 'does not modify root if there is no ContextLoaderListener' do
    assert_equality('web_root_no_contextLoaderListener', &:augment_root_context)
  end

  it 'does not modify a servlet if is not a DispatcherServlet' do
    assert_equality('web_servlet_no_DispatcherServlet', &:augment_root_context)
  end

  it 'adds a new contextInitializerClasses if it does not exist' do
    assert_equality('web_root_no_params', &:augment_root_context)
    assert_equality('web_servlet_no_params', &:augment_servlet_contexts)
    assert_equality('web_servlet_load_on_startup', &:augment_servlet_contexts)
  end

  it 'updates existing contextInitializerClasses if it does exist' do
    assert_equality('web_root_existing_params', &:augment_root_context)
    assert_equality('web_servlet_existing_params', &:augment_servlet_contexts)
    assert_equality('web_servlet_existing_load_on_startup', &:augment_servlet_contexts)
  end

  def assert_equality(fixture)
    modifier = described_class.new(Pathname.new("spec/fixtures/#{fixture}_before.xml").read)

    yield modifier

    actual   = modifier.to_s
    expected = Pathname.new("spec/fixtures/#{fixture}_after.xml").read

    expect(actual).to eq(expected)
  end

end
