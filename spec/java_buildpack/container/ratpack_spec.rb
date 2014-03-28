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
require 'java_buildpack/container/ratpack'

describe JavaBuildpack::Container::Ratpack do
  include_context 'component_helper'

  it 'should detect a dist Ratpack application',
     app_fixture: 'container_ratpack_dist' do

    expect(component.detect).to eq('ratpack=0.9.0')
  end

  it 'should detect a staged Ratpack application',
     app_fixture: 'container_ratpack_staged' do

    expect(component.detect).to eq('ratpack=0.9.0')
  end

  it 'should not detect a non-Ratpack application',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'should link classpath JARs',
     app_fixture: 'container_ratpack_staged' do

    component.compile

    lib = app_dir + 'lib'

    jar_1 = lib + 'test-jar-1.jar'
    expect(jar_1).to exist
    expect(jar_1).to be_symlink
    expect(jar_1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(lib))

    jar_2 = lib + 'test-jar-2.jar'
    expect(jar_2).to exist
    expect(jar_2).to be_symlink
    expect(jar_2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(lib))
  end

  it 'should return command',
     app_fixture: 'container_ratpack_staged' do

    expect(component.release).to eq("#{java_home.as_env_var} JAVA_OPTS=\"test-opt-2 test-opt-1 -Dratpack.port=$PORT\" " \
                                      '$PWD/bin/application')
  end

end
