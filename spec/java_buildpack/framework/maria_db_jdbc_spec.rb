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
require 'java_buildpack/framework/maria_db_jdbc'

describe JavaBuildpack::Framework::MariaDbJdbc, service_type: 'cleardb-n/a' do
  include_context 'component_helper'

  it 'should detect with cleardb-n/a service' do
    expect(component.detect).to eq("mariadb-jdbc=#{version}")
  end

  context do
    let(:vcap_services) { {} }

    it 'should not detect without cleardb-n/a service' do
      expect(component.detect).to be_nil
    end
  end

  it 'should not detect if the application already has a Maria DB driver',
     app_fixture: 'framework_mariadb_jdbc_with_driver' do
    expect(component.detect).not_to be
  end

  it 'should not detect if the application has a MySQL driver',
     app_fixture: 'framework_mariadb_jdbc_with_mysql_driver' do
    expect(component.detect).not_to be
  end

  it 'should copy the MariaDB driver to the lib directory when needed',
     cache_fixture: 'stub-mariadb-java-client.jar' do

    component.compile

    expect(additional_libs_dir + 'mariadb-jdbc-0.0.0.jar').to exist
  end

end
