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
require 'fileutils'
require 'java_buildpack/container/tomcat'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Container::Tomcat do
  include_context 'component_helper'

  let(:configuration) { { 'support' => support_configuration } }
  let(:support_configuration) { {} }
  let(:support_uri) { 'test-support-uri' }
  let(:support_version) { '1.1.1' }

  before do
    allow(application_cache).to receive(:get).with(support_uri)
                                .and_yield(Pathname.new('spec/fixtures/stub-support.jar').open)
  end

  before do
    tokenized_version = JavaBuildpack::Util::TokenizedVersion.new(support_version)

    allow(JavaBuildpack::Repository::ConfiguredItem).to receive(:find_item).with(an_instance_of(String),
                                                                                 support_configuration) do |&block|
      block.call(tokenized_version) if block
    end.and_return([tokenized_version, support_uri])
  end

  it 'should detect WEB-INF',
     app_fixture: 'container_tomcat' do

    detected = component.detect

    expect(detected).to include("tomcat=#{version}")
    expect(detected).to include("tomcat-buildpack-support=#{support_version}")
  end

  it 'should not detect when WEB-INF is absent',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'should not detect when WEB-INF is present in a Java main application',
     app_fixture: 'container_main_with_web_inf' do

    expect(component.detect).to be_nil
  end

  context do
    let(:version) { '7.0.47_10' }

    it 'should fail when a malformed version is detected',
       app_fixture: 'container_tomcat' do

      expect { component.detect }.to raise_error /Malformed version/
    end
  end

  it 'should extract Tomcat from a GZipped TAR',
     app_fixture:   'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    expect(sandbox + 'bin/catalina.sh').to exist
    expect(sandbox + 'conf/context.xml').to exist
    expect(sandbox + 'conf/server.xml').to exist
    expect(sandbox + 'lib/tomcat_buildpack_support-1.1.1.jar').to exist
  end

  it 'should link only the application files and directories to the ROOT webapp',
     app_fixture:   'container_tomcat_with_index',
     cache_fixture: 'stub-tomcat.tar.gz' do

    FileUtils.touch(app_dir + '.test-file')

    component.compile

    root_webapp = app_dir + '.java-buildpack/tomcat/webapps/ROOT'

    web_inf = root_webapp + 'WEB-INF'
    expect(web_inf).to exist
    expect(web_inf).to be_symlink
    expect(web_inf.readlink).to eq((app_dir + 'WEB-INF').relative_path_from(root_webapp))

    index = root_webapp + 'index.html'
    expect(index).to exist
    expect(index).to be_symlink
    expect(index.readlink).to eq((app_dir + 'index.html').relative_path_from(root_webapp))

    expect(root_webapp + '.test-file').not_to exist
  end

  it 'should link the Tomcat datasource JAR to the ROOT webapp when that JAR is present',
     app_fixture:   'container_tomcat',
     cache_fixture: 'stub-tomcat7.tar.gz' do

    component.compile

    web_inf_lib = app_dir + 'WEB-INF/lib'
    app_jar     = web_inf_lib + 'tomcat-jdbc.jar'
    expect(app_jar).to exist
    expect(app_jar).to be_symlink
    expect(app_jar.readlink).to eq((sandbox + 'lib/tomcat-jdbc.jar').relative_path_from(web_inf_lib))
  end

  it 'should not link the Tomcat datasource JAR to the ROOT webapp when that JAR is absent',
     app_fixture:   'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    app_jar = app_dir + 'WEB-INF/lib/tomcat-jdbc.jar'
    expect(app_jar).not_to exist
  end

  it 'should link additional libraries to the ROOT webapp',
     app_fixture:   'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    web_inf_lib = app_dir + 'WEB-INF/lib'

    test_jar_1 = web_inf_lib + 'test-jar-1.jar'
    test_jar_2 = web_inf_lib + 'test-jar-2.jar'
    expect(test_jar_1).to exist
    expect(test_jar_1).to be_symlink
    expect(test_jar_1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(web_inf_lib))

    expect(test_jar_2).to exist
    expect(test_jar_2).to be_symlink
    expect(test_jar_2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(web_inf_lib))
  end

  context do
    let(:extra_applications_dir) { app_dir + '.spring-insight/extra-applications' }

    before do
      FileUtils.mkdir_p extra_applications_dir
      FileUtils.cp_r 'spec/fixtures/framework_spring_insight', extra_applications_dir
    end

    it 'should link extra applications to the applications directory',
       app_fixture:   'container_tomcat',
       cache_fixture: 'stub-tomcat.tar.gz' do

      component.compile

      webapps_dir = sandbox + 'webapps'

      insight_test_dir = webapps_dir + 'framework_spring_insight'
      expect(insight_test_dir).to exist
      expect(insight_test_dir).to be_symlink
      expect(insight_test_dir.readlink).to eq((extra_applications_dir + 'framework_spring_insight')
                                              .relative_path_from(webapps_dir))
    end
  end

  context do
    let(:container_libs_dir) { app_dir + '.spring-insight/container-libs' }

    before do
      FileUtils.mkdir_p container_libs_dir
      FileUtils.cp_r 'spec/fixtures/framework_spring_insight/.java-buildpack/spring_insight/weaver/insight-weaver-1.2.4-CI-SNAPSHOT.jar',
                     container_libs_dir
    end

    it 'should link container libs to the tomcat lib directory',
       app_fixture:   'container_tomcat',
       cache_fixture: 'stub-tomcat.tar.gz' do

      component.compile

      lib_dir          = sandbox + 'lib'
      insight_test_lib = lib_dir + 'insight-weaver-1.2.4-CI-SNAPSHOT.jar'

      expect(insight_test_lib).to exist
      expect(insight_test_lib).to be_symlink
      expect(insight_test_lib.readlink).to eq((container_libs_dir + 'insight-weaver-1.2.4-CI-SNAPSHOT.jar')
                                              .relative_path_from(lib_dir))
    end
  end

  it 'should return command',
     app_fixture: 'container_tomcat' do

    expect(component.release).to eq("#{java_home.as_env_var} JAVA_OPTS=\"-Dhttp.port=$PORT test-opt-1 test-opt-2\" " +
                                        '$PWD/.java-buildpack/tomcat/bin/catalina.sh run')
  end

end
