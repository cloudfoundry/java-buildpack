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
require 'additional_libs_helper'
require 'application_helper'
require 'java_buildpack/util/library_utils'
require 'java_buildpack/util/play_app_post22'

module JavaBuildpack::Util

  describe PlayAppPost22 do
    include_context 'application_helper'

    context do

      let(:trigger) { PlayAppPost22.recognizes? app_dir }

      it 'should not recognize Play 2.0 applications',
         app_fixture: 'container_play_2.0_dist' do

        expect(trigger).not_to be
      end

      it 'should not recognize Play 2.1 dist applications',
         app_fixture: 'container_play_2.1_dist' do

        expect(trigger).not_to be
      end

      it 'should not recognize Play 2.1 staged applications',
         app_fixture: 'container_play_2.1_staged' do

        expect(trigger).not_to be
      end

      it 'should recognize Play 2.2 applications',
         app_fixture: 'container_play_2.2' do

        expect(trigger).to be
      end

      it 'should recognize a Play 2.2 application with a missing .bat file if there is precisely one start script',
         app_fixture: 'container_play_2.2_minus_bat_file' do

        expect(trigger).to be
      end

      it 'should not recognize a Play 2.2 application with a missing .bat file and more than one start script',
         app_fixture: 'container_play_2.2_ambiguous_start_script' do

        expect(trigger).not_to be
      end
    end

    context do

      let(:play_app) { PlayAppPost22.new app_dir }

      it 'should construct a Play 2.2 application',
         app_fixture: 'container_play_2.2' do

        play_app
      end

      it 'should fail to construct a Play application of version prior to 2.2',
         app_fixture: 'container_play_2.1_dist' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should correctly determine the version of a Play 2.2 application',
         app_fixture: 'container_play_2.2' do

        expect(play_app.version).to eq('2.2.0')
      end

      it 'should make the start script executable',
         app_fixture: 'container_play_2.2' do

        allow(play_app).to receive(:shell).with("chmod +x #{app_dir}/bin/play-application").and_return('')

        play_app.set_executable
      end

      it 'should correctly replace the bootstrap class in the start script',
         app_fixture: 'container_play_2.2' do

        play_app.replace_bootstrap 'test.class.name'

        expect((app_dir + 'bin/play-application').read).to match /declare -r app_mainclass="test.class.name"/
      end

      context do
        include_context 'additional_libs_helper'

        it 'should correctly extend the classpath',
           app_fixture: 'container_play_2.2' do

          play_app.add_libs_to_classpath LibraryUtils.lib_jars(additional_libs_dir)

          expect((app_dir + 'bin/play-application').read)
          .to match %r(declare -r app_classpath="\$app_home/\.\./\.lib/test-jar-1\.jar:\$app_home/\.\./\.lib/test-jar-2\.jar.*")
        end
      end

      it 'should correctly determine the relative path of the start script',
         app_fixture: 'container_play_2.2' do

        expect(play_app.start_script_relative).to eq('./bin/play-application')
      end

      it 'should correctly determine whether or not certain JARs are present in the lib directory',
         app_fixture: 'container_play_2.2' do

        expect(play_app.contains? 'so*st.jar').to be
        expect(play_app.contains? 'some.test.jar').to be
        expect(play_app.contains? 'nosuch.jar').not_to be
      end

      it 'should decorate Java options with -J',
         app_fixture: 'container_play_2.2' do

        expect(play_app.decorate_java_opts(%w(test-option1 test-option2))).to eq(%w(-Jtest-option1 -Jtest-option2))
      end
    end

  end

end
