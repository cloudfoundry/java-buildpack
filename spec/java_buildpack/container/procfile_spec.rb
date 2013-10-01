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
require 'fileutils'
require 'java_buildpack/container/procfile'

module JavaBuildpack::Container

  describe Procfile do

    it 'should detect with Procfile' do
      detected = Main.new(
          app_dir: 'spec/fixtures/container_none',
          configuration: { 'java_main_class' => 'test-java-main-class' }
      ).detect

      expect(detected).to be_true
    end

    it 'should return command' do
      Dir.mktmpdir do |root|
        lib_directory = File.join(root, '.lib')
        Dir.mkdir lib_directory

        command = Procfile.new(
            app_dir: root,
            java_home: 'test-java-home',
            java_opts: %w(test-opt-2 test-opt-1),
            lib_directory: lib_directory
        ).release

        expect(command).to include('PATH=test-java-home/bin:$PATH')
				expect(command).to match('.*JAVA_OPTS="test-opt-1 test-opt-2".*')
				expect(command).to include('./.lib/forego start --port $PORT')
      end
    end

  end

end
