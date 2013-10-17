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
require 'java_buildpack/util/play_app_factory'

module JavaBuildpack::Container

  describe Play do

    let(:play_instance) { double('PlayApp') }

    it 'should construct an instance using the PlayAppFactory' do
      JavaBuildpack::Util::PlayAppFactory.stub(:create).with('test-app-dir').and_return(play_instance)
      Play.new('app_dir' => 'test-app-dir')
    end

    it 'should used nil returned by the PlayAppFactory to determine the version' do
      JavaBuildpack::Util::PlayAppFactory.stub(:create).with('test-app-dir').and_return(nil)
      play = Play.new('app_dir' => 'test-app-dir')
      expect(play.detect).to be_nil
    end

    it 'should use the PlayApp returned by the PlayAppFactory to determine the version' do
      JavaBuildpack::Util::PlayAppFactory.stub(:create).with('test-app-dir').and_return(play_instance)
      play_instance.should_receive(:version).and_return('test-version')
      play = Play.new('app_dir' => 'test-app-dir')
      expect(play.detect).to eq('play-framework=test-version')
    end

    it 'should use the PlayApp returned by the PlayAppFactory to perform compilation' do
      JavaBuildpack::Util::PlayAppFactory.stub(:create).with('test-app-dir').and_return(play_instance)
      play_instance.should_receive(:set_executable)
      play_instance.should_receive(:add_libs_to_classpath)
      play_instance.should_receive(:replace_bootstrap)
      play = Play.new('app_dir' => 'test-app-dir')
      play.compile
    end

    it 'should use the PlayApp returned by the PlayAppFactory to perform release' do
      JavaBuildpack::Util::PlayAppFactory.stub(:create).with('test-app-dir').and_return(play_instance)
      play_instance.should_receive(:start_script_relative).and_return('test-start-script-relative')
      play_instance.should_receive(:decorate_java_opts).with(['some-option', '-Dhttp.port=$PORT']).and_return(['-Jsome-option', '-J-Dhttp.port=$PORT'])
      play = Play.new('app_dir' => 'test-app-dir', 'java_opts' => ['some-option'], 'java_home' => 'test-java-home')
      expect(play.release).to eq('PATH=test-java-home/bin:$PATH JAVA_HOME=test-java-home test-start-script-relative -J-Dhttp.port=$PORT -Jsome-option')
    end

  end

end
