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
require 'droplet_helper'
require 'java_buildpack/component/additional_libraries'

describe JavaBuildpack::Component::AdditionalLibraries do
  include_context 'droplet_helper'

  context do

    before do
      additional_libraries.clear
    end

    it 'should contain an added path' do
      path = droplet.sandbox + 'jar-1.jar'

      additional_libraries << path

      expect(additional_libraries).to include(path)
    end

    it 'should render as classpath' do
      additional_libraries << droplet.sandbox + 'jar-2.jar'
      additional_libraries << droplet.sandbox + 'jar-1.jar'

      expect(additional_libraries.as_classpath)
      .to eq('-cp $PWD/.java-buildpack/additional_libraries/jar-1.jar:$PWD/.java-buildpack/additional_libraries/jar-2.jar')
    end
  end

  it 'should symbolically link additional libraries' do
    additional_libraries.link_to app_dir

    test_jar_1 = app_dir + 'test-jar-1.jar'
    test_jar_2 = app_dir + 'test-jar-2.jar'
    expect(test_jar_1).to exist
    expect(test_jar_1).to be_symlink
    expect(test_jar_1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(app_dir))

    expect(test_jar_2).to exist
    expect(test_jar_2).to be_symlink
    expect(test_jar_2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(app_dir))
  end

end
