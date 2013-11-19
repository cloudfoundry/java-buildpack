# Encoding: utf-8
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
require 'java_buildpack/util/library_utils'
require 'java_buildpack/util/play_app_post22'

module JavaBuildpack::Util

  describe PlayAppPost22 do

    TEST_JAVA_OPTIONS = %w(test-option1 test-option2)

    it 'should not recognize Play 2.0 applications' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.0_dist').to be_false
    end

    it 'should not recognize Play 2.1 dist applications' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.1_dist').to be_false
    end

    it 'should not recognize Play 2.1 staged applications' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.1_staged').to be_false
    end

    it 'should recognize Play 2.2 applications' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.2').to be_true
    end

    it 'should recognize a Play 2.2 application with a missing .bat file if there is precisely one start script' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.2_minus_bat_file').to be_true
    end

    it 'should not recognize a Play 2.2 application with a missing .bat file and more than one start script' do
      expect(PlayAppPost22.recognizes? 'spec/fixtures/container_play_2.2_ambiguous_start_script').to be_false
    end

    it 'should construct a Play 2.2 application' do
      PlayAppPost22.new 'spec/fixtures/container_play_2.2'
    end

    it 'should fail to construct a Play application of version prior to 2.2' do
      expect { PlayAppPost22.new 'spec/fixtures/container_play_2.1_dist' }.to raise_error(/Unrecognized Play application/)
    end

    it 'should correctly determine the version of a Play 2.2 application' do
      play_app = PlayAppPost22.new 'spec/fixtures/container_play_2.2'
      expect(play_app.version).to eq('2.2.0')
    end

    it 'should make the start script executable' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/container_play_2.2/.', root

        play_app = PlayAppPost22.new root

        JavaBuildpack::Util::PlayAppPost22.any_instance.should_receive(:shell).with("chmod +x #{root}/bin/play-application").and_return('')

        play_app.set_executable
      end
    end

    it 'should correctly replace the bootstrap class in the start script' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/container_play_2.2/.', root

        play_app = PlayAppPost22.new root

        play_app.replace_bootstrap 'test.class.name'

        actual = File.open(File.join(root, 'bin', 'play-application'), 'r') { |file| file.read }

        expect(actual).to match(/declare -r app_mainclass="test.class.name"/)
      end
    end

    it 'should correctly extend the classpath' do
      Dir.mktmpdir do |root|
        lib_dir = File.join(root, '.lib')
        FileUtils.mkdir_p lib_dir
        FileUtils.cp 'spec/fixtures/additional_libs/test-jar-1.jar', lib_dir

        FileUtils.cp_r 'spec/fixtures/container_play_2.2/.', root

        play_app = PlayAppPost22.new root

        play_app.add_libs_to_classpath JavaBuildpack::Util::LibraryUtils.lib_jars(lib_dir)

        actual = File.open(File.join(root, 'bin', 'play-application'), 'r') { |file| file.read }

        expect(actual).to match(%r(declare -r app_classpath="\$app_home/\.\./\.lib/test-jar-1\.jar:.*"))
      end
    end

    it 'should correctly determine the relative path of the start script' do
      play_app = PlayAppPost22.new 'spec/fixtures/container_play_2.2'
      expect(play_app.start_script_relative).to eq('./bin/play-application')
    end

    it 'should correctly determine whether or not certain JARs are present in the lib directory' do
      play_app = PlayAppPost22.new 'spec/fixtures/container_play_2.2'
      expect(play_app.contains? 'so*st.jar').to be_true
      expect(play_app.contains? 'some.test.jar').to be_true
      expect(play_app.contains? 'nosuch.jar').to be_false
    end

    it 'should decorate Java options with -J' do
      play_app = PlayAppPost22.new 'spec/fixtures/container_play_2.2'
      expect(play_app.decorate_java_opts(TEST_JAVA_OPTIONS)).to eq(%w(-Jtest-option1 -Jtest-option2))
    end

  end

end
