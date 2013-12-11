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
require 'java_buildpack/container/java_main'

describe JavaBuildpack::Container::JavaMain do
  include_context 'component_helper'

  shared_context 'explicit_main_class' do
    let(:configuration) { { 'java_main_class' => 'test-java-main-class' } }
  end

  context do
    include_context 'explicit_main_class'

    it 'should detect with main class configuration' do

      expect(component.detect).to eq('java-main')
    end

  end

  it 'should detect with main class manifest entry',
     app_fixture: 'container_main' do

    expect(component.detect).to eq('java-main')
  end

  it 'should not detect without main class manifest entry',
     app_fixture: 'container_main_no_main_class' do

    expect(component.detect).to be_nil
  end

  it 'should not detect without manifest' do

    expect(component.detect).to be_nil
  end

  context do
    include_context 'explicit_main_class'

    it 'should return command' do

      expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                          "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                          'test-java-main-class')
    end
  end

  it 'should return additional classpath entries when Class-Path is specified',
     app_fixture: 'container_main' do

    expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                        '$PWD/.additional_libs/test-jar-2.jar:$PWD/alpha.jar:$PWD/bravo.jar:' +
                                        "$PWD/charlie.jar #{java_opts_str} test-main-class")
  end

  context do
    let(:configuration) { { 'java_main_class' => 'test-java-main-class', 'arguments' => 'some arguments' } }

    it 'should return command line arguments when they are specified' do

      expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                          "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                          'test-java-main-class some arguments')
    end
  end

  it 'should release Spring boot applications with a JarLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                        "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                        'org.springframework.boot.loader.JarLauncher --server.port=$PORT')
  end

  it 'should release Spring boot applications with a WarLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_war_launcher' do

    expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                        "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                        'org.springframework.boot.loader.WarLauncher --server.port=$PORT')
  end

  it 'should release Spring boot applications with a PropertiesLauncher in the MANIFEST.MF by specifying a port',
     app_fixture: 'container_main_spring_boot_properties_launcher' do

    expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                        "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                        'org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
  end

  context do
    let(:configuration) { { 'java_main_class' => 'org.springframework.boot.loader.JarLauncher' } }

    it 'should release Spring boot applications with a JarLauncher in the configuration by specifying a port' do

      expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                          "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                          'org.springframework.boot.loader.JarLauncher --server.port=$PORT')
    end
  end

  context do
    let(:configuration) { { 'java_main_class' => 'org.springframework.boot.loader.WarLauncher' } }

    it 'should release Spring boot applications with a WarLauncher in the configuration by specifying a port' do

      expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                          "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                          'org.springframework.boot.loader.WarLauncher --server.port=$PORT')
    end
  end

  context do
    let(:configuration) { { 'java_main_class' => 'org.springframework.boot.loader.PropertiesLauncher' } }

    it 'should release Spring boot applications with a PropertiesLauncher in the configuration by specifying a port' do

      expect(component.release).to eq("#{java_home.root}/bin/java -cp $PWD/.:$PWD/.additional_libs/test-jar-1.jar:" +
                                          "$PWD/.additional_libs/test-jar-2.jar #{java_opts_str} " +
                                          'org.springframework.boot.loader.PropertiesLauncher --server.port=$PORT')
    end
  end

  def java_opts_str
    java_opts.sort.join(' ')
  end

end
