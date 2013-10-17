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
require 'java_buildpack/util/base_play_app'

module JavaBuildpack::Util

  describe BasePlayApp do

    TEST_DIRECTORY_NAME = 'test-dir'

    MISSING_METHOD_REGEX = /Method .* must be defined/

    TEST_JAVA_OPTS = %w(test-option1 test-option2)

    let(:base_play_app) { StubBasePlayApp.new TEST_DIRECTORY_NAME }

    let(:base_play_app_raw) { StubBasePlayAppRaw.new TEST_DIRECTORY_NAME }

    it 'should recognize a Play application' do
      expect(StubBasePlayApp.recognizes? 'spec/fixtures/container_play_2.2').to be_true
    end

    it 'should not recognize a non-Play application' do
      expect(StubBasePlayApp.recognizes? 'spec/fixtures/container_main').to be_false
    end

    it 'should assign application directory to an instance variable' do
      expect(base_play_app_raw.app_dir).to eq(TEST_DIRECTORY_NAME)
    end

    it 'should fail if methods are unimplemented' do
      expect { base_play_app_raw.add_libs_to_classpath [] }.to raise_error(MISSING_METHOD_REGEX)
      expect { base_play_app_raw.start_script_relative }.to raise_error(MISSING_METHOD_REGEX)
    end

    it 'should set the Play script to be executable' do
      app = base_play_app
      base_play_app.stub(:shell)
      base_play_app.should_receive(:shell).with('chmod +x test-dir/application_root/start')
      app.set_executable
    end

    it 'should correctly replace the bootstrap class in the start script' do
      Dir.mktmpdir do |root|
        FileUtils.cp_r 'spec/fixtures/container_play_2.1_dist/.', root

        play_app = StubBasePlayApp.new root

        play_app.replace_bootstrap 'test.class.name'

        actual = File.open(File.join(root, 'application_root', 'start'), 'r') { |file| file.read }

        expect(actual).to_not match(/play.core.server.NettyServer/)
        expect(actual).to match(/test.class.name/)
      end
    end

    it 'should be able to find JARs in the classpath directory' do
      play_app = StubBasePlayApp.new 'spec/fixtures/container_play_2.1_dist'
      expect(play_app.contains?('some.test.jar')).to be_true
    end

    it 'should be able to find root and version' do
      root, version = StubBasePlayApp.test_root_and_version 'spec/fixtures/container_play_2.1_dist'
      expect(root).to eq('spec/fixtures/container_play_2.1_dist/application_root')
      expect(version).to eq('2.1.4')
    end

    it 'should not decorate Java options' do
      play_app = StubBasePlayApp.new 'spec/fixtures/container_play_2.1_dist'
      expect(play_app.decorate_java_opts(TEST_JAVA_OPTS)).to eq(TEST_JAVA_OPTS)
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
