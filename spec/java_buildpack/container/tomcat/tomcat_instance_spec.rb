# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/container/tomcat/tomcat_instance'

describe JavaBuildpack::Container::TomcatInstance do
  include_context 'with component help'

  let(:component_id) { 'tomcat' }

  it 'always detects' do
    expect(component.detect).to eq("tomcat-instance=#{version}")
  end

  context do
    let(:version) { '7.0.47_10' }

    it 'fails when a malformed version is detected',
       app_fixture: 'container_tomcat' do

      expect { component.detect }.to raise_error(/Malformed version/)
    end
  end

  it 'extracts Tomcat from a GZipped TAR',
     app_fixture: 'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    expect(sandbox + 'bin/catalina.sh').to exist
    expect(sandbox + 'conf/context.xml').to exist
    expect(sandbox + 'conf/server.xml').to exist
  end

  it 'configures for Tomcat 7',
     app_fixture: 'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile
    expect((sandbox + 'conf/context.xml').read).to match(/<Context allowLinking='true'>/)
    expect((sandbox + 'conf/server.xml').read)
      .to match(%r{<Listener className='org.apache.catalina.core.JasperListener'/>})
  end

  context do
    let(:version) { '8.0.12' }

    it 'configures for Tomcat 8',
       app_fixture: 'container_tomcat',
       cache_fixture: 'stub-tomcat.tar.gz' do

      component.compile
      expect((sandbox + 'conf/context.xml').read).to match(%r{<Context>\s*<Resources allowLinking='true'/>})
      expect((sandbox + 'conf/server.xml').read)
        .not_to match(%r{<Listener className='org.apache.catalina.core.JasperListener'/>})
    end
  end

  it 'links only the application files and directories to the ROOT webapp',
     app_fixture: 'container_tomcat_with_index',
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

  context do
    let(:configuration) { { 'context_path' => '/first-segment/second-segment' } }

    it 'links only the application files and directories to the first-segment#second-segment webapp',
       app_fixture: 'container_tomcat_with_index',
       cache_fixture: 'stub-tomcat.tar.gz' do

      FileUtils.touch(app_dir + '.test-file')

      component.compile

      root_webapp = app_dir + '.java-buildpack/tomcat/webapps/first-segment#second-segment'

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
  end

  it 'links the Tomcat datasource JAR to the ROOT webapp when that JAR is present',
     app_fixture: 'container_tomcat',
     cache_fixture: 'stub-tomcat7.tar.gz' do

    component.compile

    web_inf_lib = app_dir + 'WEB-INF/lib'
    app_jar = web_inf_lib + 'tomcat-jdbc.jar'
    expect(app_jar).to exist
    expect(app_jar).to be_symlink
    expect(app_jar.readlink).to eq((sandbox + 'lib/tomcat-jdbc.jar').relative_path_from(web_inf_lib))
  end

  it 'does not link the Tomcat datasource JAR to the ROOT webapp when that JAR is absent',
     app_fixture: 'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    app_jar = app_dir + 'WEB-INF/lib/tomcat-jdbc.jar'
    expect(app_jar).not_to exist
  end

  it 'links additional libraries to the ROOT webapp',
     app_fixture: 'container_tomcat',
     cache_fixture: 'stub-tomcat.tar.gz' do

    component.compile

    web_inf_lib = app_dir + 'WEB-INF/lib'

    test_jar1 = web_inf_lib + 'test-jar-1.jar'
    test_jar2 = web_inf_lib + 'test-jar-2.jar'
    expect(test_jar1).to exist
    expect(test_jar1).to be_symlink
    expect(test_jar1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(web_inf_lib))

    expect(test_jar2).to exist
    expect(test_jar2).to be_symlink
    expect(test_jar2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(web_inf_lib))
  end

end
