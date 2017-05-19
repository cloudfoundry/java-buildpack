# Encoding: utf-8

# Cloud Foundry Java Buildpack
# Copyright 2017 the original author or authors.
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
require 'fileutils'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/jre/ibmjre_like'
require 'java_buildpack/jre/ibmjre'

describe JavaBuildpack::Jre::IBMJRE do
  include_context 'component_helper'
  let(:component) { StubIBMJRE.new context }

  let(:java_home) { JavaBuildpack::Component::MutableJavaHome.new }
  let(:configuration) do
    { 'jre' => jre_configuration,
      'jvmkill_agent' => jvmkill_agent_configuration }
  end

  let(:jre_configuration) { instance_double('jre_configuration') }

  let(:jvmkill_agent_configuration) { {} }

  it 'supports anyway' do
    expect(component.supports?).to be
  end

  it 'creates Ibmjava instance' do
    allow_any_instance_of(StubIBMJRE).to receive(:supports?).and_return false
    allow(JavaBuildpack::Jre::IbmjreLike)
      .to receive(:new).with(sub_configuration_context(jre_configuration).merge(component_name: 'Stub IBMJRE'))
    allow(JavaBuildpack::Jre::JvmkillAgent)
      .to receive(:new).with(sub_configuration_context(jvmkill_agent_configuration))
    component.sub_components context
  end
end

class StubIBMJRE < JavaBuildpack::Jre::IBMJRE
  public :command, :sub_components
  def supports?
    super
  end
end

def sub_configuration_context(configuration)
  cntxt = context.clone
  cntxt[:configuration] = configuration
  cntxt
end
