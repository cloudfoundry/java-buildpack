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
require 'pathname'
require 'java_buildpack/util/configuration_utils'
require 'application_helper'
require 'logging_helper'

describe JavaBuildpack::Util::ConfigurationUtils do
  include_context 'application_helper'
  include_context 'logging_helper'

  it 'should read from app dir' do
    component_id = String.new('app_only')
    app_root = Pathname.new(File.expand_path('./spec/fixtures/container_tomcat_with_config/'))
    expect(JavaBuildpack::Util::ConfigurationUtils.load_from_app_dir(component_id, app_root)['location']).to eq('app')

    component_id = String.new('app_and_system')
    expect(JavaBuildpack::Util::ConfigurationUtils.load_from_app_dir(component_id, app_root)['location']).to eq('app')
  end

  it 'should read from system dir' do
    component_id = String.new('system_only')
    app_root = Pathname.new(File.expand_path('./spec/fixtures/container_tomcat_with_config/'))
    expect(JavaBuildpack::Util::ConfigurationUtils.load(component_id, app_root)['location']).to eq('system')
    expect(JavaBuildpack::Util::ConfigurationUtils.load_from_app_dir(component_id, app_root)['location']).to eq('system')
  end

end
