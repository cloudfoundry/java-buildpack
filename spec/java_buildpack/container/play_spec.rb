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
require 'java_buildpack/container/play'

module JavaBuildpack::Container

  TEST_JAVA_HOME = 'test-java-home'
  TEST_JAVA_OPTS = ['test-java-opt']
  TEST_PLAY_APP = 'spec/fixtures/container_play'

  describe Play do

    it 'should not detect an application without a start script' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_main',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect an application with a start directory' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_play_invalid',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should not detect an application which is too deeply nested in the application directory' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_play_too_deep',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should fail if a Play application is in more than one directory' do
      expect do
        Play.new(
            app_dir: 'spec/fixtures/container_play_duplicate',
            configuration: {}
        )
      end.to raise_error(/multiple/)
    end

    it 'should detect a dist application with a start script and a suitable Play JAR' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_play',
          configuration: {}
      ).detect

      expect(detected).to eq('play-0.0-0.0.0')
    end

    it 'should detect a staged application with a start script and a suitable Play JAR' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_play_staged',
          configuration: {}
      ).detect

      expect(detected).to eq('play-0.0')
    end

    it 'should not detect an application with a start script but no suitable Play JAR' do
      detected = Play.new(
          app_dir: 'spec/fixtures/container_play_like',
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should make the start script executable in the compile step' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/container_play/.', root

        play = Play.new(
            app_dir: root,
            configuration: {}
        )

        play.should_receive(:shell).with("chmod +x #{root}/application_root/start").and_return('')

        play.compile
      end
    end

    it 'should replace the server command in the start script' do
      Dir.mktmpdir do |root|
        start_script = File.join root, 'application_root', 'start'
        FileUtils.cp_r 'spec/fixtures/container_play/.', root

        Play.new(
            app_dir: root,
            configuration: {}
        ).compile

        actual = File.open(start_script, 'r') { |file| file.read }

        expect(actual).to_not match(/play.core.server.NettyServer/)
        expect(actual).to match(/org.cloudfoundry.reconfiguration.play.Bootstrap/)
      end
    end

    it 'should add additional libraries to classpath in (e.g. Play 2.1.3) dist application' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'
        start_script = File.join root, 'application_root', 'start'

        FileUtils.cp_r 'spec/fixtures/container_play/.', root
        Dir.mkdir lib_directory
        FileUtils.cp 'spec/fixtures/additional_libs/test-jar-1.jar', lib_directory

        Play.new(
            app_dir: root,
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        actual = File.open(start_script, 'r') { |file| file.read }

        expect(actual).to match(%r(classpath="\$scriptdir/.\./\.lib/test-jar-1\.jar:))
      end
    end

    it 'should add additional libraries to lib directory in Play 2.0 dist application' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'

        FileUtils.cp_r 'spec/fixtures/container_play_2.0/.', root
        Dir.mkdir lib_directory
        FileUtils.cp 'spec/fixtures/additional_libs/test-jar-1.jar', lib_directory

        Play.new(
            app_dir: root,
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        relative = File.readlink(File.join root, 'application_root', 'lib', 'test-jar-1.jar')
        actual = Pathname.new(File.join root, 'application_root', 'lib', 'test-jar-1.jar').realpath.to_s
        expected = Pathname.new(File.join lib_directory, 'test-jar-1.jar').realpath.to_s

        expect(relative).to_not eq(expected)
        expect(actual).to eq(expected)
      end
    end

    it 'should add additional libraries to staged directory in staged application' do
      Dir.mktmpdir do |root|
        lib_directory = File.join root, '.lib'

        FileUtils.cp_r 'spec/fixtures/container_play_staged/.', root
        Dir.mkdir lib_directory
        FileUtils.cp 'spec/fixtures/additional_libs/test-jar-1.jar', lib_directory

        Play.new(
            app_dir: root,
            lib_directory: lib_directory,
            configuration: {}
        ).compile

        relative = File.readlink(File.join root, 'staged', 'test-jar-1.jar')
        actual = Pathname.new(File.join root, 'staged', 'test-jar-1.jar').realpath.to_s
        expected = Pathname.new(File.join lib_directory, 'test-jar-1.jar').realpath.to_s

        expect(relative).to_not eq(expected)
        expect(actual).to eq(expected)
      end
    end

    it 'should produce the correct command in the release step' do
      command = Play.new(
          app_dir: TEST_PLAY_APP,
          configuration: {},
          java_home: TEST_JAVA_HOME,
          java_opts: TEST_JAVA_OPTS
      ).release

      expect(command).to eq("PATH=#{TEST_JAVA_HOME}/bin:$PATH JAVA_HOME=#{TEST_JAVA_HOME} ./application_root/start -Dhttp.port=$PORT #{TEST_JAVA_OPTS[0]}")
    end

  end

end
