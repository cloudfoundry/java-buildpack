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
require 'java_buildpack/util/play_app_pre22_staged'

module JavaBuildpack::Util

  describe PlayAppPre22Staged do

    it 'should not recognize Play 2.0 dist applications' do
      expect(PlayAppPre22Staged.recognizes? 'spec/fixtures/container_play_2.0_dist').to be_false
    end

    it 'should not recognize Play 2.1 dist applications' do
      expect(PlayAppPre22Staged.recognizes? 'spec/fixtures/container_play_2.1_dist').to be_false
    end

    it 'should recognize Play 2.1 staged (or equivalently 2.0 staged) applications' do
      expect(PlayAppPre22Staged.recognizes? 'spec/fixtures/container_play_2.1_staged').to be_true
    end

    it 'should not recognize Play 2.2 applications' do
      expect(PlayAppPre22Staged.recognizes? 'spec/fixtures/container_play_2.2').to be_false
    end

    it 'should fail to construct a Play 2.0 dist application' do
      expect { PlayAppPre22Staged.new 'spec/fixtures/container_play_2.0_dist' }.to raise_error(/Unrecognized Play application/)
    end

    it 'should fail to construct a Play 2.1 dist application' do
      expect { PlayAppPre22Staged.new 'spec/fixtures/container_play_2.1_dist' }.to raise_error(/Unrecognized Play application/)
    end

    it 'should construct a Play 2.1 staged (or equivalently 2.0 staged) application' do
      PlayAppPre22Staged.new 'spec/fixtures/container_play_2.1_staged'
    end

    it 'should fail to construct a Play 2.2 application' do
      expect { PlayAppPre22Staged.new 'spec/fixtures/container_play_2.2' }.to raise_error(/Unrecognized Play application/)
    end

    it 'should correctly determine the version of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      play_app = PlayAppPre22Staged.new 'spec/fixtures/container_play_2.1_staged'
      expect(play_app.version).to eq('2.1.4')
    end

    it 'should make the start script executable' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/container_play_2.1_staged/.', root

        play_app = PlayAppPre22Staged.new root

        JavaBuildpack::Util::PlayAppPre22Staged.any_instance.should_receive(:shell).with("chmod +x #{root}/start").and_return('')

        play_app.set_executable
      end
    end

    it 'should add additional libraries to staged directory of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      Dir.mktmpdir do |root|
        lib_dir = File.join(root, '.lib')
        FileUtils.mkdir_p lib_dir
        FileUtils.cp 'spec/fixtures/additional_libs/test-jar-1.jar', lib_dir

        FileUtils.cp_r 'spec/fixtures/container_play_2.1_staged/.', root

        play_app = PlayAppPre22Staged.new root

        play_app.add_libs_to_classpath JavaBuildpack::Util::LibraryUtils.lib_jars(lib_dir)

        relative = File.readlink(File.join root, 'staged', 'test-jar-1.jar')
        actual = Pathname.new(File.join root, 'staged', 'test-jar-1.jar').realpath.to_s
        expected = Pathname.new(File.join lib_dir, 'test-jar-1.jar').realpath.to_s

        expect(relative).to_not eq(expected)
        expect(actual).to eq(expected)
      end
    end

    it 'should correctly determine the relative path of the start script of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      play_app = PlayAppPre22Staged.new 'spec/fixtures/container_play_2.1_staged'
      expect(play_app.start_script_relative).to eq('./start')
    end

    it 'should correctly determine whether or not certain JARs are present in the lib directory of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      play_app = PlayAppPre22Staged.new 'spec/fixtures/container_play_2.1_staged'
      expect(play_app.contains? 'so*st.jar').to be_true
      expect(play_app.contains? 'some.test.jar').to be_true
      expect(play_app.contains? 'nosuch.jar').to be_false
    end

  end

end
