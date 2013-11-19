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
require 'application_helper'
require 'java_buildpack/util/base_play_app'

module JavaBuildpack::Util

  describe BasePlayApp do
    include_context 'application_helper'

    let(:base_play_app) { StubBasePlayApp.new app_dir }

    let(:base_play_app_raw) { StubBasePlayAppRaw.new app_dir }

    it 'should recognize a Play application',
       app_fixture: 'container_play_2.2' do

      expect(StubBasePlayApp.recognizes? app_dir).to be
    end

    it 'should not recognize a non-Play application',
       app_fixture: 'container_main' do

      expect(StubBasePlayApp.recognizes? app_dir).not_to be
    end

    it 'should assign application directory to an instance variable' do
      expect(base_play_app_raw.app_dir).to eq(app_dir)
    end

    it 'should fail if methods are unimplemented' do
      expect { base_play_app_raw.add_libs_to_classpath [] }.to raise_error /Method .* must be defined/
      expect { base_play_app_raw.start_script_relative }.to raise_error /Method .* must be defined/
    end

    it 'should set the Play script to be executable' do
      expect(base_play_app).to receive(:shell).with("chmod +x #{app_dir + 'application_root/start'}")

      base_play_app.set_executable
    end

    it 'should correctly replace the bootstrap class in the start script',
       app_fixture: 'container_play_2.1_dist' do

      play_app = StubBasePlayApp.new app_dir
      play_app.replace_bootstrap 'test.class.name'

      actual = (app_dir + 'application_root/start').read

      expect(actual).not_to match /play.core.server.NettyServer/
      expect(actual).to match /test.class.name/
    end

    it 'should be able to find JARs in the classpath directory',
       app_fixture: 'container_play_2.1_dist' do

      play_app = StubBasePlayApp.new app_dir
      expect(play_app.contains? 'some.test.jar').to be
    end

    it 'should be able to find root and version',
       app_fixture: 'container_play_2.1_dist' do

      root, version = StubBasePlayApp.test_root_and_version app_dir
      expect(root).to eq((app_dir + 'application_root').to_s)
      expect(version).to eq('2.1.4')
    end

    it 'should not decorate Java options',
       app_fixture: 'container_play_2.1_dist' do

      play_app = StubBasePlayApp.new app_dir
      expect(play_app.decorate_java_opts(%w(test-opt-2 test-opt-1))).to eq(%w(test-opt-2 test-opt-1))
    end

  end

  class StubBasePlayAppRaw < BasePlayApp

    def initialize(app_dir)
      super(app_dir)
      @play_root = app_dir
    end

    attr_reader :app_dir

    attr_reader :play_root

  end

  class StubBasePlayApp < BasePlayApp

    def initialize(app_dir)
      super(app_dir)
      @play_root = File.join(app_dir, 'application_root')
    end

    def self.start_script(app_dir)
      File.join(app_dir, 'start')
    end

    attr_reader :app_dir

    attr_reader :play_root

    def self.test_root_and_version(app_dir)
      root_and_version app_dir
    end

  end

end
