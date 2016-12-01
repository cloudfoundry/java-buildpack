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
require 'java_buildpack/container/java_main'
require 'java_buildpack/util/qualify_path'

describe JavaBuildpack::Container::JavaMain do
  include JavaBuildpack::Util
  include_context 'component_helper'

  shared_context 'explicit_main_class' do
    let(:configuration) { { 'java_main_class' => 'test-java-main-class' } }
  end

  context do
    include_context 'explicit_main_class'

    it 'detects with main class configuration' do

      expect(component.detect).to eq('java-main')
    end

  end

  it 'detects with main class manifest entry',
     app_fixture: 'container_main' do

    expect(component.detect).to eq('java-main')
  end

  it 'does not detect without main class manifest entry',
     app_fixture: 'container_main_no_main_class' do

    expect(component.detect).to be_nil
  end

  it 'does not detect without manifest' do

    expect(component.detect).to be_nil
  end

  it 'links additional libraries to the lib directory',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    component.compile

    lib = app_dir + 'lib'

    test_jar_1 = lib + 'test-jar-1.jar'
    test_jar_2 = lib + 'test-jar-2.jar'
    expect(test_jar_1).to exist
    expect(test_jar_1).to be_symlink
    expect(test_jar_1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(lib))

    expect(test_jar_2).to exist
    expect(test_jar_2).to be_symlink
    expect(test_jar_2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(lib))
  end

  context do
    include_context 'explicit_main_class'

    it 'returns command' do

      expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 ' \
                                        "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                        '-cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:$PWD/' \
                                        '.additional_libs/test-jar-2.jar test-java-main-class')
    end
  end

  it 'returns additional classpath entries when Class-Path is specified',
     app_fixture: 'container_main' do

    expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 ' \
                                      "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                      '-cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:$PWD/' \
                                      '.additional_libs/test-jar-2.jar:$PWD/alpha.jar:$PWD/bravo.jar:$PWD/' \
                                      'charlie.jar test-main-class')
  end

  context do
    let(:configuration) { { 'java_main_class' => 'test-java-main-class', 'arguments' => 'some arguments' } }

    it 'returns command line arguments when they are specified' do

      expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 ' \
                                        "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                        '-cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:$PWD/.additional_libs/' \
                                        'test-jar-2.jar test-java-main-class some arguments')
    end
  end

  it 'releases Spring boot applications with a JarLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 SERVER_PORT=$PORT ' \
                                      "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                      '-cp $PWD/. org.springframework.boot.loader.JarLauncher')
  end

  it 'releases Spring boot applications with a WarLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_war_launcher' do

    expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 SERVER_PORT=$PORT ' \
                                      "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                      '-cp $PWD/. org.springframework.boot.loader.WarLauncher')
  end

  it 'releases Spring boot applications with a PropertiesLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_properties_launcher' do

    expect(component.release).to eq('JAVA_OPTS="test-opt-2 test-opt-1" && test-var-2 test-var-1 SERVER_PORT=$PORT ' \
                                      "eval exec #{qualify_path java_home.root, droplet.root}/bin/java $JAVA_OPTS " \
                                      '-cp $PWD/. org.springframework.boot.loader.PropertiesLauncher')
  end

end
