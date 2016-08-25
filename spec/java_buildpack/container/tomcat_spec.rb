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
require 'fileutils'
require 'java_buildpack/container/tomcat'
require 'java_buildpack/container/tomcat/tomcat_insight_support'
require 'java_buildpack/container/tomcat/tomcat_instance'
require 'java_buildpack/container/tomcat/tomcat_lifecycle_support'
require 'java_buildpack/container/tomcat/tomcat_logging_support'
require 'java_buildpack/container/tomcat/tomcat_access_logging_support'
require 'java_buildpack/container/tomcat/tomcat_redis_store'

describe JavaBuildpack::Container::Tomcat do
  include_context 'component_helper'

  let(:component) { StubTomcat.new context }

  let(:configuration) do
    { 'tomcat'                 => tomcat_configuration,
      'lifecycle_support'      => lifecycle_support_configuration,
      'logging_support'        => logging_support_configuration,
      'access_logging_support' => access_logging_support_configuration,
      'redis_store'            => redis_store_configuration,
      'external_configuration' => tomcat_external_configuration }
  end

  let(:tomcat_configuration) { { 'external_configuration_enabled' => false } }

  let(:lifecycle_support_configuration) { instance_double('lifecycle-support-configuration') }

  let(:logging_support_configuration) { instance_double('logging-support-configuration') }

  let(:access_logging_support_configuration) { instance_double('logging-support-configuration') }

  let(:redis_store_configuration) { instance_double('redis-store-configuration') }

  let(:tomcat_external_configuration) { instance_double('tomcat_external_configuration') }

  it 'detects WEB-INF',
     app_fixture: 'container_tomcat' do

    expect(component.supports?).to be
  end

  it 'does not detect when WEB-INF is absent',
     app_fixture: 'container_main' do

    expect(component.supports?).not_to be
  end

  it 'does not detect when WEB-INF is present in a Java main application',
     app_fixture: 'container_main_with_web_inf' do

    expect(component.supports?).not_to be
  end

  it 'creates submodules' do
    allow(JavaBuildpack::Container::TomcatInstance)
      .to receive(:new).with(sub_configuration_context(tomcat_configuration))
    allow(JavaBuildpack::Container::TomcatLifecycleSupport)
      .to receive(:new).with(sub_configuration_context(lifecycle_support_configuration))
    allow(JavaBuildpack::Container::TomcatLoggingSupport)
      .to receive(:new).with(sub_configuration_context(logging_support_configuration))
    allow(JavaBuildpack::Container::TomcatAccessLoggingSupport)
      .to receive(:new).with(sub_configuration_context(access_logging_support_configuration))
    allow(JavaBuildpack::Container::TomcatRedisStore)
      .to receive(:new).with(sub_configuration_context(redis_store_configuration))
    allow(JavaBuildpack::Container::TomcatInsightSupport).to receive(:new).with(context)

    component.sub_components context
  end

  it 'returns command' do
    expect(component.command).to eq("test-var-2 test-var-1 #{java_home.as_env_var} JAVA_OPTS=\"test-opt-2 " \
                                      'test-opt-1 -Dhttp.port=$PORT" exec $PWD/.java-buildpack/tomcat/bin/catalina.sh' \
                                      ' run')
  end

  context do

    let(:tomcat_configuration) { { 'external_configuration_enabled' => true } }

    it 'creates submodule TomcatExternalConfiguration' do
      allow(JavaBuildpack::Container::TomcatExternalConfiguration)
        .to receive(:new).with(sub_configuration_context(tomcat_external_configuration))

      component.sub_components context
    end
  end

end

class StubTomcat < JavaBuildpack::Container::Tomcat

  public :command, :sub_components, :supports?

end

def sub_configuration_context(configuration)
  c                 = context.clone
  c[:configuration] = configuration
  c
end
