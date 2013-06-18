# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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
require 'java_buildpack/container/tomcat'

module JavaBuildpack::Container

  describe Tomcat do

    VERSION = JavaBuildpack::Util::TokenizedVersion.new('7.0.40')

    DETAILS = [VERSION, 'test-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(VERSION).and_return(DETAILS)
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect

      expect(detected).to eq('tomcat-7.0.40')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_none',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should fail when a malformed version is detected' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(JavaBuildpack::Util::TokenizedVersion.new('7.0.40_0'))
      expect { Tomcat.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect }.to raise_error(/Malformed\ Tomcat\ version/)
    end

    it 'should extract Tomcat from a GZipped TAR' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(VERSION).and_return(DETAILS)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-tomcat.tar.gz'))

        Tomcat.new(
          :app_dir => root,
          :configuration => {}
        ).compile

        tomcat_dir = File.join root, '.tomcat'
        conf_dir = File.join tomcat_dir, 'conf'

        catalina = File.join tomcat_dir, 'bin', 'catalina.sh'
        expect(File.exists?(catalina)).to be_true

        context = File.join conf_dir, 'context.xml'
        expect(File.exists?(context)).to be_true

        server = File.join conf_dir, 'server.xml'
        expect(File.exists?(server)).to be_true
      end
    end

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(VERSION).and_return(DETAILS)

      command = Tomcat.new(
        :app_dir => 'spec/fixtures/container_tomcat',
        :java_home => 'test-java-home',
        :java_opts => [ 'test-opt-2', 'test-opt-1' ],
        :configuration => {}).release

      expect(command).to eq('JAVA_HOME=test-java-home JAVA_OPTS="-Dhttp.port=$PORT test-opt-1 test-opt-2" spec/fixtures/container_tomcat/.tomcat/bin/catalina.sh run')
    end

  end

end
