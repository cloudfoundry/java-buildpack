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
require 'java_buildpack/container/spring_boot_cli'

module JavaBuildpack::Container

  describe SpringBootCli do

    SPRING_BOOT_CLI_VERSION = JavaBuildpack::Util::TokenizedVersion.new('0.5.0_x-y.z')

    SPRING_BOOT_CLI_URI = 'test-spring-boot-cli-uri'

    SPRING_BOOT_CLI_DETAILS = [SPRING_BOOT_CLI_VERSION, SPRING_BOOT_CLI_URI]

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should not detect a non-Groovy project' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_main',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect a .groovy directory' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/dot_groovy',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect if the application has a WEB-INF directory' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_spring_boot_cli_groovy_with_web_inf',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect if one of the Groovy files is not a POGO' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_spring_boot_cli_non_pogo',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect if one of the Groovy files has a main() method' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_spring_boot_cli_main_method',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should detect if there are Groovy files and they are all POGOs with no main method and there is no WEB-INF directory' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      detected = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_spring_boot_cli_valid_app',
          configuration: {}
      ).detect

      expect(detected).to include("spring-boot-cli-#{SPRING_BOOT_CLI_VERSION}")
    end

    it 'should extract Spring Boot CLI from a ZIP' do
      Dir.mktmpdir do |root|
        Dir['spec/fixtures/container_spring_boot_cli_valid_app/*'].each { |file| system "cp -r #{file} #{root}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
        .and_return(SPRING_BOOT_CLI_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(SPRING_BOOT_CLI_URI).and_yield(File.open('spec/fixtures/stub-spring-boot-cli.tar.gz'))

        SpringBootCli.new(
            app_dir: root,
            configuration: {}
        ).compile

        spring = File.join root, '.spring-boot-cli', 'bin', 'spring'
        expect(File.exists?(spring)).to be_true
      end
    end

    it 'should link classpath JARs' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{lib_directory}" }
        Dir['spec/fixtures/container_spring_boot_cli_valid_app/*'].each { |file| system "cp -r #{file} #{root}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
        .and_return(SPRING_BOOT_CLI_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with(SPRING_BOOT_CLI_URI).and_yield(File.open('spec/fixtures/stub-spring-boot-cli.tar.gz'))

        SpringBootCli.new(
            app_dir: root,
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        lib = File.join root, '.spring-boot-cli', 'lib'
        jar_1 = File.join(lib, 'test-jar-1.jar')
        expect(File.exist?(jar_1)).to be_true
        expect(File.symlink?(jar_1)).to be_true
        jar_2 = File.join(lib, 'test-jar-2.jar')
        expect(File.exist?(jar_2)).to be_true
        expect(File.symlink?(jar_2)).to be_true
        expect(File.exist?(File.join(lib, 'test-text.txt'))).to be_false
      end
    end

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(SPRING_BOOT_CLI_VERSION) if block }
      .and_return(SPRING_BOOT_CLI_DETAILS)
      command = SpringBootCli.new(
          app_dir: 'spec/fixtures/container_spring_boot_cli_valid_app',
          java_home: 'test-java-home',
          java_opts: %w(test-opt-2 test-opt-1),
          configuration: {}
      ).release

      expect(command).to eq('JAVA_HOME=test-java-home JAVA_OPTS="test-opt-1 test-opt-2" .spring-boot-cli/bin/spring run --local directory/pogo_4.groovy pogo_1.groovy pogo_2.groovy pogo_3.groovy -- --server.port=$PORT')
    end

  end

end
