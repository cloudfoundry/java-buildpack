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
require 'java_buildpack/util/filtering_pathname'
require 'java_buildpack/util/play/post22'

describe JavaBuildpack::Util::Play::Post22 do
  include_context 'component_helper'

  let(:play_app) { described_class.new(droplet) }

  before do
    java_home
    java_opts
  end

  it 'should raise error if root method is unimplemented' do
    expect { play_app.send(:root) }.to raise_error "Method 'root' must be defined"
  end

  context app_fixture: 'container_play_2.2_staged' do

    before do
      allow(play_app).to receive(:root).and_return(droplet.root)
    end

    it 'should correctly determine the version of a Play 2.2 application' do
      expect(play_app.version).to eq('2.2.0')
    end

    it 'should correctly extend the classpath' do
      play_app.compile

      expect((app_dir + 'bin/play-application').read)
      .to match 'declare -r app_classpath="\$app_home/../.additional_libs/test-jar-1.jar:\$app_home/../.additional_libs/test-jar-2.jar:'
    end

    it 'should return command' do
      expect(play_app.release).to eq("PATH=#{java_home.root}/bin:$PATH #{java_home.as_env_var} $PWD/bin/play-application " +
                                         '-Jtest-opt-2 -Jtest-opt-1 -J-Dhttp.port=$PORT')
    end

  end

end
