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
require 'java_buildpack/util/play_app_pre22_dist'

module JavaBuildpack::Util

  describe PlayAppPre22Dist do
    include_context 'application_helper'

    context do

      let(:trigger) { PlayAppPre22Dist.recognizes? app_dir }

      it 'should recognize Play 2.0 dist applications',
         app_fixture: 'container_play_2.0_dist' do

        expect(trigger).to be
      end

      it 'should recognize Play 2.1 dist applications',
         app_fixture: 'container_play_2.1_dist' do

        expect(trigger).to be
      end

      it 'should not recognize Play 2.1 staged (or equivalently 2.0 staged) applications',
         app_fixture: 'container_play_2.1_staged' do

        expect(trigger).not_to be
      end

      it 'should not recognize Play 2.2 applications',
         app_fixture: 'container_play_2.2' do

        expect(trigger).not_to be
      end
    end

    context do

      let(:play_app) { PlayAppPre22Dist.new app_dir }

      it 'should construct a Play 2.0 dist application',
         app_fixture: 'container_play_2.0_dist' do

        play_app
      end

      it 'should construct a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        play_app
      end

      it 'should fail to construct a Play 2.1 staged (or equivalently 2.0 staged) application',
         app_fixture: 'container_play_2.1_staged' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should fail to construct a Play 2.2 application',
         app_fixture: 'container_play_2.2' do

        expect { play_app }.to raise_error /Unrecognized Play application/
      end

      it 'should correctly determine the version of a Play 2.0 dist application',
         app_fixture: 'container_play_2.0_dist' do

        expect(play_app.version).to eq('2.0')
      end

      it 'should correctly determine the version of a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        expect(play_app.version).to eq('2.1.4')
      end

      it 'should make the start script executable',
         app_fixture: 'container_play_2.1_dist' do

        allow(play_app).to receive(:shell).with("chmod +x #{app_dir}/application_root/start").and_return('')

        play_app.set_executable
      end

      it 'should correctly replace the bootstrap class in the start script of a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        play_app.replace_bootstrap 'test.class.name'

        actual = (app_dir + 'application_root/start').read

        expect(actual).not_to match /play.core.server.NettyServer/
        expect(actual).to match /test.class.name/
      end

      context do
        include_context 'additional_libs_helper'

        it 'should add additional libraries to lib directory of a Play 2.0 dist application',
           app_fixture: 'container_play_2.0_dist' do

          play_app.add_libs_to_classpath LibraryUtils.lib_jars(additional_libs_dir)

          lib_dir = app_dir + 'application_root/lib'
          test_jar_1 = lib_dir + 'test-jar-1.jar'
          test_jar_2 = lib_dir + 'test-jar-2.jar'

          expect(test_jar_1).to exist
          expect(test_jar_1).to be_symlink
          expect(test_jar_1.readlink).to eq((additional_libs_dir + 'test-jar-1.jar').relative_path_from(lib_dir))

          expect(test_jar_2).to exist
          expect(test_jar_2).to be_symlink
          expect(test_jar_2.readlink).to eq((additional_libs_dir + 'test-jar-2.jar').relative_path_from(lib_dir))
        end

        it 'should correctly extend the classpath of a Play 2.1 dist application',
           app_fixture: 'container_play_2.1_dist' do

          play_app.add_libs_to_classpath LibraryUtils.lib_jars(additional_libs_dir)

          expect((app_dir + 'application_root/start').read)
          .to match %r(classpath="\$scriptdir/.\./\.lib/test-jar-1\.jar:\$scriptdir/.\./\.lib/test-jar-2\.jar:)
        end
      end

      it 'should correctly determine the relative path of the start script of a Play 2.0 dist application',
         app_fixture: 'container_play_2.0_dist' do

        expect(play_app.start_script_relative).to eq('./application_root/start')
      end

      it 'should correctly determine the relative path of the start script of a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        expect(play_app.start_script_relative).to eq('./application_root/start')
      end

      it 'should correctly determine whether or not certain JARs are present in the lib directory of a Play 2.0 dist application',
         app_fixture: 'container_play_2.0_dist' do

        expect(play_app.contains? 'so*st.jar').to be
        expect(play_app.contains? 'some.test.jar').to be
        expect(play_app.contains? 'nosuch.jar').not_to be
      end

      it 'should correctly determine whether or not certain JARs are present in the lib directory of a Play 2.1 dist application',
         app_fixture: 'container_play_2.1_dist' do

        expect(play_app.contains? 'so*st.jar').to be
        expect(play_app.contains? 'some.test.jar').to be
        expect(play_app.contains? 'nosuch.jar').not_to be
      end
    end

  end

end
