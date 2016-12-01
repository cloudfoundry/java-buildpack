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
require 'java_buildpack/framework/maria_db_jdbc'

describe JavaBuildpack::Framework::MariaDbJDBC do
  include_context 'component_helper'

  it 'does not detect without a service containing a mysql tag' do
    expect(component.detect).to be_nil
  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/mariadb/, 'uri').and_return(true)
      allow(services).to receive(:one_service?).with(/mysql/, 'uri').and_return(false)
    end

    it 'detects with service containing a mariadb tag' do
      expect(component.detect).to eq("maria-db-jdbc=#{version}")
    end

    it 'does not detect if the application already has a Maria DB driver',
       app_fixture: 'framework_mariadb_jdbc_with_driver' do

      expect(component.detect).to be_nil
    end

    it 'does not detect if the application has a MySQL driver',
       app_fixture: 'framework_mariadb_jdbc_with_mysql_driver' do

      expect(component.detect).to be_nil
    end

    it 'downloads the MariaDB driver when needed',
       cache_fixture: 'stub-mariadb-java-client.jar' do

      component.compile

      expect(sandbox + "maria_db_jdbc-#{version}.jar").to exist
    end

    it 'adds the MariaDB driver to the additional libraries when needed',
       cache_fixture: 'stub-mariadb-java-client.jar' do

      component.release

      expect(additional_libraries).to include(sandbox + "maria_db_jdbc-#{version}.jar")
    end

  end

  context do

    before do
      allow(services).to receive(:one_service?).with(/mariadb/, 'uri').and_return(false)
      allow(services).to receive(:one_service?).with(/mysql/, 'uri').and_return(true)
    end

    it 'detects with service containing a mysql tag' do
      expect(component.detect).to eq("maria-db-jdbc=#{version}")
    end

  end

end
