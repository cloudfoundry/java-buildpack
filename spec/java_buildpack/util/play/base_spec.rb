# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'droplet_helper'
require 'fileutils'
require 'java_buildpack/util/play/base'

describe JavaBuildpack::Util::Play::Base do
  include_context 'with droplet help'

  let(:play) { described_class.new(droplet) }

  it 'does not support with no start script' do
    allow(play).to receive(:start_script).and_return nil

    expect(play.supports?).not_to be
  end

  it 'does not support with a non-existent start script' do
    allow(play).to receive(:start_script).and_return(droplet.root + 'bin/start')

    expect(play.supports?).not_to be
  end

  it 'does not support with no play JAR' do
    allow(play).to receive(:start_script).and_return(droplet.root + 'bin/start')
    allow(play).to receive(:lib_dir).and_return(droplet.root + 'lib')

    FileUtils.mkdir_p app_dir + 'bin'
    FileUtils.touch app_dir + 'bin/start'

    expect(play.supports?).not_to be
  end

  it 'raises error if augment_classpath method is unimplemented' do
    expect { play.send(:augment_classpath) }.to raise_error "Method 'augment_classpath' must be defined"
  end

  it 'raises error if java_opts method is unimplemented' do
    expect { play.send(:java_opts) }.to raise_error "Method 'java_opts' must be defined"
  end

  it 'raises error if lib_dir method is unimplemented' do
    expect { play.send(:lib_dir) }.to raise_error "Method 'lib_dir' must be defined"
  end

  it 'raises error if start_script method is unimplemented' do
    expect { play.send(:start_script) }.to raise_error "Method 'start_script' must be defined"
  end

  context nil, app_fixture: 'container_play_2.2_staged' do

    let(:lib_dir) { droplet.root + 'lib' }

    let(:play_jar) { lib_dir + 'com.typesafe.play.play_2.10-2.2.0.jar' }

    let(:start_script) { app_dir + 'bin/play-application' }

    before do
      allow(play).to receive(:augment_classpath)
      allow(play).to receive(:lib_dir).and_return(lib_dir)
      allow(play).to receive(:start_script).and_return(start_script)
    end

    it 'supports application' do
      expect(play.supports?).to be
    end

    it 'returns a version' do
      expect(play.version).to eq('2.2.0')
    end

    it 'sets the start script to be executable' do
      expect(start_script).not_to be_executable

      play.compile

      expect(start_script).to be_executable
    end

    it 'determines whether or not certain JARs are present in the lib directory' do
      expect(play.jar?(/so.*st.jar/)).to be
      expect(play.jar?(/some.test.jar/)).to be
      expect(play.jar?(/nosuch.jar/)).not_to be
    end

    it 'replaces the bootstrap class' do
      play.compile

      content = start_script.read
      expect(content).not_to match(/play.core.server.NettyServer/)
      expect(content).to match(/org.cloudfoundry.reconfiguration.play.Bootstrap/)
    end
  end

end
