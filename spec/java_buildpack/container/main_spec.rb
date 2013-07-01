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
require 'java_buildpack/container/main'

module JavaBuildpack::Container

  describe Main do

    it 'should detect with main class configuration' do
      detected = Main.new(
        :app_dir => 'spec/fixtures/container_none',
        :configuration => { 'java_main_class' => 'test-java-main-class' }).detect

      expect(detected).to be_true
    end

    it 'should detect with main class manifest entry' do
      detected = Main.new(
        :app_dir => 'spec/fixtures/container_main',
        :configuration => { }).detect

      expect(detected).to be_true
    end

    it 'should not detect without main class manifest entry' do
      detected = Main.new(
        :app_dir => 'spec/fixtures/container_main_no_main_class',
        :configuration => { }).detect

      expect(detected).to be_false
    end

    it 'should not detect without manifest' do
      detected = Main.new(
        :app_dir => 'spec/fixtures/container_main_none',
        :configuration => { }).detect

      expect(detected).to be_false
    end

    it 'should return command' do
      command = Main.new(
        :java_home => 'test-java-home',
        :java_opts => [ 'test-opt-2', 'test-opt-1' ],
        :configuration => { 'java_main_class' => 'test-java-main-class' }).release

      expect(command).to eq('test-java-home/bin/java -cp . test-opt-1 test-opt-2 test-java-main-class')
    end

    it 'should return command line arguments when they are specified' do
      command = Main.new(
        :java_home => 'test-java-home',
        :java_opts => [],
        :configuration => { 'java_main_class' => 'test-java-main-class',
                            'arguments' => 'some arguments'
        }).release

      expect(command).to eq('test-java-home/bin/java -cp . test-java-main-class some arguments')
    end
  end

end

module Test
  class StubContainer
  end
end
