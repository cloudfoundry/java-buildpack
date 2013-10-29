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
require 'fileutils'
require 'java_buildpack/application'
require 'java_buildpack/container/tomcat'

module JavaBuildpack::Container

  describe Tomcat do

    TOMCAT_VERSION = JavaBuildpack::Util::TokenizedVersion.new('7.0.40')

    TOMCAT_DETAILS = [TOMCAT_VERSION, 'test-tomcat-uri']

    SUPPORT_VERSION = JavaBuildpack::Util::TokenizedVersion.new('1.0.0')

    SUPPORT_DETAILS = [SUPPORT_VERSION, 'test-support-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
      .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)
      detected = Tomcat.new(
          app_dir: 'spec/fixtures/container_tomcat',
          application: JavaBuildpack::Application.new('spec/fixtures/container_tomcat'),
          configuration: {}
      ).detect

      expect(detected).to include('tomcat=7.0.40')
      expect(detected).to include('tomcat-buildpack-support=1.0.0')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Tomcat.new(
          app_dir: 'spec/fixtures/container_main',
          application: JavaBuildpack::Application.new('spec/fixtures/container_main'),
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect when WEB-INF is present in a Java main application' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
      .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)
      detected = Tomcat.new(
          app_dir: 'spec/fixtures/container_main_with_web_inf',
          application: JavaBuildpack::Application.new('spec/fixtures/container_main_with_web_inf'),
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should fail when a malformed version is detected' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JavaBuildpack::Util::TokenizedVersion.new('7.0.40_0')) if block }
      .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)
      expect do
        Tomcat.new(
            app_dir: 'spec/fixtures/container_tomcat',
            application: JavaBuildpack::Application.new('spec/fixtures/container_tomcat'),
            configuration: {}
        ).detect
      end.to raise_error(/Malformed\ version/)
    end

    it 'should extract Tomcat from a GZipped TAR' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Tomcat.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        tomcat_dir = File.join root, '.tomcat'
        conf_dir = File.join tomcat_dir, 'conf'

        catalina = File.join tomcat_dir, 'bin', 'catalina.sh'
        expect(File.exists?(catalina)).to be_true

        context = File.join conf_dir, 'context.xml'
        expect(File.exists?(context)).to be_true

        server = File.join conf_dir, 'server.xml'
        expect(File.exists?(server)).to be_true

        support = File.join tomcat_dir, 'lib', 'tomcat-buildpack-support-1.0.0.jar'
        expect(File.exists?(support)).to be_true
      end
    end

    it 'should link only the application files and directories to the ROOT webapp' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')
        FileUtils.touch File.join(root, 'index.html')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        application = JavaBuildpack::Application.new(root)

        FileUtils.touch File.join(root, '.test-file')

        Tomcat.new(
            app_dir: root,
            application: application,
            configuration: {}
        ).compile

        root_webapp = File.join root, '.tomcat', 'webapps', 'ROOT'

        web_inf = File.join root_webapp, 'WEB-INF'
        expect(File.exists?(web_inf)).to be_true
        expect(File.readlink(web_inf)).to eq('../../../WEB-INF')

        index = File.join root_webapp, 'index.html'
        expect(File.exists?(index)).to be_true
        expect(File.readlink(index)).to eq('../../../index.html')

        test_file = File.join root_webapp, '.test_file'
        expect(File.exists?(test_file)).to be_false
      end
    end

    it 'should link the Tomcat datasource JAR to the ROOT webapp when that JAR is present' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')
        lib_directory = File.join(root, '.lib')
        Dir.mkdir lib_directory

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat7.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        application = JavaBuildpack::Application.new(root)

        Tomcat.new(
            app_dir: root,
            application: application,
            configuration: {},
            lib_directory: lib_directory
        ).compile

        root_webapp = File.join root, '.tomcat', 'webapps', 'ROOT'

        tomcat_datasource_jar = File.join root_webapp, 'WEB-INF', 'lib', 'tomcat-jdbc.jar'
        expect(File.exists?(tomcat_datasource_jar)).to be_true
        expect(File.readlink(tomcat_datasource_jar)).to eq('../../.lib/tomcat-jdbc.jar')

        tomcat_datasource_link_in_lib_directory = File.join lib_directory, 'tomcat-jdbc.jar'
        expect(File.exists?(tomcat_datasource_link_in_lib_directory))
        expect(File.readlink(tomcat_datasource_link_in_lib_directory)).to eq('../.tomcat/lib/tomcat-jdbc.jar')
      end
    end

    it 'should not link the Tomcat datasource JAR to the ROOT webapp when that JAR is absent' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')
        lib_directory = File.join(root, '.lib')
        Dir.mkdir lib_directory

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        application = JavaBuildpack::Application.new(root)

        Tomcat.new(
            app_dir: root,
            application: application,
            configuration: {},
            lib_directory: lib_directory
        ).compile

        root_webapp = File.join root, '.tomcat', 'webapps', 'ROOT'

        tomcat_datasource_jar = File.join root_webapp, 'WEB-INF', 'lib', 'tomcat-jdbc.jar'
        expect(File.exists?(tomcat_datasource_jar)).to be_false
      end
    end

    it 'should link additional libraries to the ROOT webapp' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join root, 'WEB-INF'
        lib_directory = File.join root, '.lib'
        Dir.mkdir lib_directory

        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{lib_directory}" }

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Tomcat.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        lib = File.join root, '.tomcat', 'webapps', 'ROOT', 'WEB-INF', 'lib'
        test_jar_1 = File.join lib, 'test-jar-1.jar'
        test_jar_2 = File.join lib, 'test-jar-2.jar'
        test_text = File.join lib, 'test-text.txt'

        expect(File.exists?(test_jar_1)).to be_true
        expect(File.symlink?(test_jar_1)).to be_true
        expect(File.readlink(test_jar_1)).to eq('../../.lib/test-jar-1.jar')

        expect(File.exists?(test_jar_2)).to be_true
        expect(File.symlink?(test_jar_2)).to be_true
        expect(File.readlink(test_jar_2)).to eq('../../.lib/test-jar-2.jar')

        expect(File.exists?(test_text)).to be_false
      end
    end

    it 'should link extra applications to the applications directory' do
      Dir.mktmpdir do |root|
        extra_applications_dir = File.join(root, '.extra-applications')
        Dir.mkdir extra_applications_dir
        Dir.mkdir File.join root, 'WEB-INF'
        system "cp -r spec/fixtures/framework_spring_insight #{extra_applications_dir}"

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Tomcat.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        insight_test_dir = File.join root, '.tomcat', 'webapps', 'framework_spring_insight'
        expect(File.exists?(insight_test_dir)).to be_true
        expect(File.symlink?(insight_test_dir)).to be_true
      end
    end

    it 'should link container libs to the tomcat lib directory' do
      Dir.mktmpdir do |root|
        container_libs_directory = File.join(root, '.container-libs')
        Dir.mkdir container_libs_directory
        Dir.mkdir File.join root, 'WEB-INF'
        system "cp -r spec/fixtures/framework_spring_insight/.insight/weaver/insight-weaver-1.2.4-CI-SNAPSHOT.jar #{container_libs_directory}"

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
        .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-tomcat-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))
        application_cache.stub(:get).with('test-support-uri').and_yield(File.open('spec/fixtures/stub-support.jar'))

        Tomcat.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        insight_test_lib = File.join root, '.tomcat', 'lib', 'insight-weaver-1.2.4-CI-SNAPSHOT.jar'
        expect(File.exists?(insight_test_lib)).to be_true
        expect(File.symlink?(insight_test_lib)).to be_true
      end
    end

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(TOMCAT_VERSION) if block }
      .and_return(TOMCAT_DETAILS, SUPPORT_DETAILS)

      command = Tomcat.new(
          app_dir: 'spec/fixtures/container_tomcat',
          application: JavaBuildpack::Application.new('spec/fixtures/container_tomcat'),
          java_home: 'test-java-home',
          java_opts: %w(test-opt-2 test-opt-1),
          configuration: {}
      ).release

      expect(command).to eq('JAVA_HOME=test-java-home JAVA_OPTS="-Dhttp.port=$PORT test-opt-1 test-opt-2" .tomcat/bin/catalina.sh run')
    end

  end

end
