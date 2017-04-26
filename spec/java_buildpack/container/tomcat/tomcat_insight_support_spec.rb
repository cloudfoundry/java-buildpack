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
require 'component_helper'
require 'fileutils'
require 'java_buildpack/container/tomcat/tomcat_insight_support'

describe JavaBuildpack::Container::TomcatInsightSupport do
  include_context 'component_helper'

  let(:component_id) { 'tomcat' }

  it 'always returns nil from detect' do
    expect(component.detect).to be_nil
  end

  it 'does nothing during release' do
    component.release
  end

  context do
    let(:container_libs_dir) { app_dir + '.spring-insight/container-libs' }

    before do
      FileUtils.mkdir_p container_libs_dir
      FileUtils.cp_r 'spec/fixtures/framework_spring_insight/.java-buildpack/spring_insight/weaver/' \
                     'insight-weaver-1.2.4-CI-SNAPSHOT.jar', container_libs_dir
    end

    it 'links container libs to the tomcat lib directory' do

      component.compile

      lib_dir          = sandbox + 'lib'
      insight_test_lib = lib_dir + 'insight-weaver-1.2.4-CI-SNAPSHOT.jar'

      expect(insight_test_lib).to exist
      expect(insight_test_lib).to be_symlink
      expect(insight_test_lib.readlink).to eq((container_libs_dir + 'insight-weaver-1.2.4-CI-SNAPSHOT.jar')
                                                .relative_path_from(lib_dir))
    end
  end

end
