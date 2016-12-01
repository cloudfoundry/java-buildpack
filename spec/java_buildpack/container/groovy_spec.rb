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
require 'java_buildpack/container/groovy'

describe JavaBuildpack::Container::Groovy do
  include_context 'component_helper'

  it 'does not detect a non-Groovy project',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a .groovy directory',
     app_fixture: 'container_groovy_dot_groovy' do

    expect(component.detect).to be_nil
  end

  it 'detects a Groovy file with a main() method',
     app_fixture: 'container_groovy_main_method' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'detects a Groovy file with non-POGO',
     app_fixture: 'container_groovy_non_pogo' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'does not detect a Groovy file with non-POGO and at least one .class file',
     app_fixture: 'container_groovy_non_pogo_with_class_file' do

    expect(component.detect).to be_nil
  end

  it 'does not detect a Groovy file from Ratpack',
     app_fixture: 'container_groovy_ratpack' do

    expect(component.detect).to be_nil
  end

  it 'detects a Groovy file with #!',
     app_fixture: 'container_groovy_shebang' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'detects a Groovy file which has a shebang but which also contains a class',
     app_fixture: 'container_groovy_shebang_containing_class' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  context do
    let(:version) { '2.1.5_10' }

    it 'fails when a malformed version is detected',
       app_fixture: 'container_groovy_main_method' do

      expect { component.detect }.to raise_error(/Malformed version/)
    end
  end

  it 'extracts Groovy from a ZIP',
     app_fixture:   'container_groovy_main_method',
     cache_fixture: 'stub-groovy.zip' do

    component.compile

    expect(sandbox + 'bin/groovy').to exist
  end

  it 'returns command',
     app_fixture: 'container_groovy_main_method' do

    expect(component.release).to eq("#{env_vars_str} #{java_home.as_env_var} JAVA_OPTS=#{java_opts_str} exec " \
                                    '$PWD/.java-buildpack/groovy/bin/groovy -cp $PWD/.additional_libs/test-jar-1.jar:' \
                                    '$PWD/.additional_libs/test-jar-2.jar Application.groovy Alpha.groovy ' \
                                    'directory/Beta.groovy invalid.groovy')
  end

  it 'returns command with included JARs',
     app_fixture: 'container_groovy_with_jars' do

    expect(component.release).to eq("#{env_vars_str} #{java_home.as_env_var} JAVA_OPTS=#{java_opts_str} exec " \
                                    '$PWD/.java-buildpack/groovy/bin/groovy -cp $PWD/.additional_libs/test-jar-1.jar:' \
                                    '$PWD/.additional_libs/test-jar-2.jar:$PWD/Alpha.jar:$PWD/directory/Beta.jar ' \
                                    'Application.groovy invalid.groovy')
  end

  def env_vars_str
    environment_variables.join(' ')
  end

  def java_opts_str
    "\"#{java_opts.join(' ')}\""
  end

end
