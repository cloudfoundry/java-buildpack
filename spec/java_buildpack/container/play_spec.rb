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

    let(:app_dir) { 'test-app-dir' }
    let(:java_home) { 'test-java-home' }
    let(:play_instance) { double('PlayApp') }

    before do
      allow(JavaBuildpack::Util::PlayAppFactory).to receive(:create).with(app_dir).and_return(play_instance)
    end

    it 'should construct an instance using the PlayAppFactory' do
      Play.new(
          app_dir: app_dir
      )
    end

    it 'should used nil returned by the PlayAppFactory to determine the version' do
      allow(JavaBuildpack::Util::PlayAppFactory).to receive(:create).with('test-app-dir').and_return(nil)

      play = Play.new(
          app_dir: app_dir
      )

      expect(play.detect).to be_nil
    end

    it 'should use the PlayApp returned by the PlayAppFactory to determine the version' do
      allow(play_instance).to receive(:version).and_return('test-version')

      play = Play.new(
          app_dir: app_dir
      )

      expect(play.detect).to eq('play-framework=test-version')
    end

    it 'should use the PlayApp returned by the PlayAppFactory to perform compilation' do
      expect(play_instance).to receive(:set_executable)
      expect(play_instance).to receive(:add_libs_to_classpath)
      expect(play_instance).to receive(:replace_bootstrap)

      Play.new(
          app_dir: app_dir
      ).compile
    end

    it 'should use the PlayApp returned by the PlayAppFactory to perform release' do
      allow(play_instance).to receive(:start_script_relative).and_return('test-start-script-relative')
      allow(play_instance).to receive(:decorate_java_opts).with(%w(some-option -Dhttp.port=$PORT))
                              .and_return(%w(-Jsome-option -J-Dhttp.port=$PORT))

      play = Play.new(
          app_dir: app_dir,
          java_opts: %w(some-option),
          java_home: java_home
      )

      expect(play.release).to eq("PATH=#{java_home}/bin:$PATH JAVA_HOME=#{java_home} test-start-script-relative " +
                                     '-J-Dhttp.port=$PORT -Jsome-option')
    end

  end

end
