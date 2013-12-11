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
require 'component_helper'
require 'java_buildpack/util/play/pre22_staged'

describe JavaBuildpack::Util::Play::Pre22Staged do
  include_context 'component_helper'

  before do
    java_home
    java_opts
  end

  context do

    let(:trigger) { described_class.new(droplet).supports? }

    it 'should not recognize non-applications' do
      expect(trigger).not_to be
    end

    it 'should not recognize Play 2.0 dist applications',
       app_fixture: 'container_play_2.0_dist' do

      expect(trigger).not_to be
    end

    it 'should not recognize Play 2.1 dist applications',
       app_fixture: 'container_play_2.1_dist' do

      expect(trigger).not_to be
    end

    it 'should recognize Play 2.1 staged (or equivalently 2.0 staged) applications',
       app_fixture: 'container_play_2.1_staged' do

      expect(trigger).to be
    end

    it 'should not recognize Play 2.2 dist applications',
       app_fixture: 'container_play_2.2_dist' do

      expect(trigger).not_to be
    end

    it 'should not recognize Play 2.2 staged applications',
       app_fixture: 'container_play_2.2_staged' do

      expect(trigger).not_to be
    end
  end

  context app_fixture: 'container_play_2.1_staged' do

    let(:play_app) { described_class.new(droplet) }

    it 'should correctly determine the version of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      expect(play_app.version).to eq('2.1.4')
    end

    it 'should add additional libraries to staged directory of a Play 2.1 staged (or equivalently 2.0 staged) application' do
      play_app.compile

      staged_dir = app_dir + 'staged'
      test_jar_1 = staged_dir + 'test-jar-1.jar'
      test_jar_2 = staged_dir + 'test-jar-2.jar'

      expect(test_jar_1).to exist
      expect(test_jar_1).to be_symlink
      expect(test_jar_1.readlink).to eq((additional_libs_directory + 'test-jar-1.jar').relative_path_from(staged_dir))

      expect(test_jar_2).to exist
      expect(test_jar_2).to be_symlink
      expect(test_jar_2.readlink).to eq((additional_libs_directory + 'test-jar-2.jar').relative_path_from(staged_dir))
    end

    it 'should return command' do
      expect(play_app.release).to eq("PATH=#{java_home.root}/bin:$PATH #{java_home.as_env_var} $PWD/start " +
                                         'test-opt-2 test-opt-1 -Dhttp.port=$PORT')
    end

  end

end
