# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

  it 'raises error if root method is unimplemented' do
    expect { play_app.send(:root) }.to raise_error "Method 'root' must be defined"
  end

  context nil, app_fixture: 'container_play_2.2_staged' do

    before do
      allow(play_app).to receive(:root).and_return(droplet.root)
    end

    it 'determines the version of a Play 2.2 application' do
      expect(play_app.version).to eq('2.2.0')
    end

    it 'extends the classpath' do
      play_app.compile

      expect((app_dir + 'bin/play-application').read)
        .to match 'declare -r app_classpath="\$app_home/../.additional_libs/test-jar-1.jar:' \
        '\$app_home/../.additional_libs/test-jar-2.jar:'
    end

    it 'returns command' do
      expect(play_app.release).to eq('test-var-2 test-var-1 PATH=$PWD/.test-java-home/bin:$PATH ' \
      "#{java_home.as_env_var} exec $PWD/bin/play-application ${JAVA_OPTS//-/-J-}")
    end

    context do
      let(:java_opts) do
        super() << '-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : \'.' \
        '*instance_id[": ]*"\([a-z0-9]\+\)".*\')'
      end

      it 'allows options with expressions' do
        play_app.release

        expect(java_opts).to include('-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : \'.' \
        '*instance_id[": ]*"\([a-z0-9]\+\)".*\')')
      end
    end

  end

end
