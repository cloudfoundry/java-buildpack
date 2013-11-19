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
require 'java_buildpack/util/play_app_pre22_staged'

module JavaBuildpack::Util

  describe PlayAppPre22Staged do
    include_context 'application_helper'

    context do

      let(:trigger) { PlayAppPre22Staged.recognizes? app_dir }

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

      it 'should not recognize Play 2.2 applications',
         app_fixture: 'container_play_2.2' do

        expect(trigger).not_to be
      end
    end

    context do

      let(:play_app) { PlayAppPre22Staged.new app_dir }

      it 'should fail to construct a Play 2.0 dist application',
         app_fixture: 'container_play_2.0_dist' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should fail to construct a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should construct a Play 2.1 staged (or equivalently 2.0 staged) application',
         app_fixture: 'container_play_2.1_staged' do

        play_app
      end

      it 'should fail to construct a Play 2.2 application',
         app_fixture: 'container_play_2.2' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should correctly determine the version of a Play 2.1 staged (or equivalently 2.0 staged) application',
         app_fixture: 'container_play_2.1_staged' do

        expect(play_app.version).to eq('2.1.4')
      end

      it 'should make the start script executable',
         app_fixture: 'container_play_2.1_staged' do

        allow(play_app).to receive(:shell).with("chmod +x #{app_dir}/start").and_return('')

        play_app.set_executable
      end

      context do
        include_context 'additional_libs_helper'

        it 'should add additional libraries to staged directory of a Play 2.1 staged (or equivalently 2.0 staged) application',
           app_fixture: 'container_play_2.1_staged' do

          play_app.add_libs_to_classpath LibraryUtils.lib_jars(additional_libs_dir)

          staged_dir = app_dir + 'staged'
          test_jar_1 = staged_dir + 'test-jar-1.jar'
          test_jar_2 = staged_dir + 'test-jar-2.jar'

          expect(test_jar_1).to exist
          expect(test_jar_1).to be_symlink
          expect(test_jar_1.readlink).to eq((additional_libs_dir + 'test-jar-1.jar').relative_path_from(staged_dir))

          expect(test_jar_2).to exist
          expect(test_jar_2).to be_symlink
          expect(test_jar_2.readlink).to eq((additional_libs_dir + 'test-jar-2.jar').relative_path_from(staged_dir))
        end
      end

      it 'should correctly determine the relative path of the start script of a Play 2.1 staged (or equivalently 2.0 staged) application',
         app_fixture: 'container_play_2.1_staged' do

        expect(play_app.start_script_relative).to eq('./start')
      end

      it 'should correctly determine whether or not certain JARs are present in the lib directory of a Play 2.1 staged (or equivalently 2.0 staged) application',
         app_fixture: 'container_play_2.1_staged' do

        expect(play_app.contains? 'so*st.jar').to be
        expect(play_app.contains? 'some.test.jar').to be
        expect(play_app.contains? 'nosuch.jar').not_to be
      end
    end

  end

end
