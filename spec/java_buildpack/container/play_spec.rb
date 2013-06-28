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

    it 'should detect an application with a start script and a suitable Play JAR' do
      detected = Play.new(
          :app_dir => 'spec/fixtures/container_play',
          :configuration => {}).detect

      expect(detected).to eq('Play')
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
      play.should_receive(:`).with('chmod +x spec/fixtures/container_play/start').and_return('')
      detected = play.compile
    end

    it 'should produce the correct command in the release step' do
      command = Play.new(
          :app_dir => TEST_PLAY_APP,
          :configuration => {},
          :java_home => TEST_JAVA_HOME,
          :java_opts => TEST_JAVA_OPTS).release

      expect(command).to eq("PATH=#{TEST_JAVA_HOME}/bin:$PATH JAVA_HOME=#{TEST_JAVA_HOME} ./start -Dhttp.port=$PORT #{TEST_JAVA_OPTS[0]}")
    end

  end

end