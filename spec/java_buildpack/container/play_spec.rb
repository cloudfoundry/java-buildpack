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
require 'java_buildpack/container/play'

module JavaBuildpack::Container

  TEST_JAVA_HOME = 'test-java-home'
  TEST_JAVA_OPTS = ['test-java-opt']
  TEST_PLAY_APP = 'spec/fixtures/container_play'

  describe Play do

    it 'should not detect an application without a start script' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_main',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should not detect an application with a start directory' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play_invalid',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should not detect an application which is too deeply nested in the application directory' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play_too_deep',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should fail if a Play application is in more than one directory' do
      expect {Play.new(
          :app_dir => 'spec/fixtures/container_play_duplicate',
          :configuration => {})}.to raise_error(/multiple/)
    end

    it 'should detect an application with a start script and a suitable Play JAR' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play',
          :configuration => {}).detect

      expect(detected).to eq('play')
    end

    it 'should detect a staged application with a start script and a suitable Play JAR' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play_staged',
          :configuration => {}).detect

      expect(detected).to eq('play')
    end

    it 'should not detect an application with a start script but no suitable Play JAR' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play_like',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should make the start script executable in the compile step' do
      play = Play.new(
          :app_dir => 'spec/fixtures/container_play',
          :configuration => {})

      play.should_receive(:system).with('chmod +x spec/fixtures/container_play/application_root/start').and_return('')

      play.compile
    end

    it 'should link additional libraries to staged' do
      Dir.mktmpdir do |root|
        additional_lib_directory = File.join root, '.lib'
        staged_directory = File.join root, 'staged'

        Dir.mkdir additional_lib_directory
        Dir.mkdir staged_directory
        FileUtils.touch File.join root, 'start'
        FileUtils.touch File.join staged_directory, 'play_0.0.0.jar'
        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{additional_lib_directory}" }

        Play.new(
          :app_dir => root,
          :lib_directory => additional_lib_directory,
          :configuration => {}).compile

        test_jar_1 = File.join staged_directory, 'test-jar-1.jar'
        test_jar_2 = File.join staged_directory, 'test-jar-2.jar'
        test_text = File.join staged_directory, 'test-text.txt'

        expect(File.exists?(test_jar_1)).to be_true
        expect(File.symlink?(test_jar_1)).to be_true
        expect(File.readlink(test_jar_1)).to eq('../.lib/test-jar-1.jar')

        expect(File.exists?(test_jar_2)).to be_true
        expect(File.symlink?(test_jar_2)).to be_true
        expect(File.readlink(test_jar_2)).to eq('../.lib/test-jar-2.jar')

        expect(File.exists?(test_text)).to be_false
      end
    end

    it 'should link additional libraries to lib' do
      Dir.mktmpdir do |root|
        additional_lib_directory = File.join root, '.lib'
        lib_directory = File.join root, 'staged'

        Dir.mkdir additional_lib_directory
        Dir.mkdir lib_directory
        FileUtils.touch File.join root, 'start'
        FileUtils.touch File.join lib_directory, 'play_0.0.0.jar'
        Dir['spec/fixtures/additional_libs/*'].each { |file| system "cp #{file} #{additional_lib_directory}" }

        Play.new(
          :app_dir => root,
          :lib_directory => additional_lib_directory,
          :configuration => {}).compile

        test_jar_1 = File.join lib_directory, 'test-jar-1.jar'
        test_jar_2 = File.join lib_directory, 'test-jar-2.jar'
        test_text = File.join lib_directory, 'test-text.txt'

        expect(File.exists?(test_jar_1)).to be_true
        expect(File.symlink?(test_jar_1)).to be_true
        expect(File.readlink(test_jar_1)).to eq('../.lib/test-jar-1.jar')

        expect(File.exists?(test_jar_2)).to be_true
        expect(File.symlink?(test_jar_2)).to be_true
        expect(File.readlink(test_jar_2)).to eq('../.lib/test-jar-2.jar')

        expect(File.exists?(test_text)).to be_false
      end
    end

    it 'should produce the correct command in the release step' do
      command = Play.new(
          :app_dir => TEST_PLAY_APP,
          :configuration => {},
          :java_home => TEST_JAVA_HOME,
          :java_opts => TEST_JAVA_OPTS).release

      expect(command).to eq("PATH=#{TEST_JAVA_HOME}/bin:$PATH JAVA_HOME=#{TEST_JAVA_HOME} ./application_root/start -Dhttp.port=$PORT #{TEST_JAVA_OPTS[0]}")
    end

  end

end
