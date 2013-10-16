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

require 'logger'
require 'spec_helper'
require 'java_buildpack/buildpack'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack::Util

  describe JavaMainUtils do

    TEST_CLASS_NAME = 'test-java-main-class'

    it 'should use a main class configuration in a configuration file' do
      JavaBuildpack::Buildpack.stub(:configuration).with('JavaMain', kind_of(Logger)) do
        { 'java_main_class' => TEST_CLASS_NAME }
      end
      JavaBuildpack::Util::JavaMainUtils.main_class('').should eq(TEST_CLASS_NAME)
    end

    it 'should use a main class configuration in a configuration parameter' do
      JavaBuildpack::Util::JavaMainUtils.main_class('', { 'java_main_class' => TEST_CLASS_NAME }).should eq(TEST_CLASS_NAME)
    end

    it 'should use a main class in the manifest of the application' do
      JavaBuildpack::Buildpack.stub(:configuration).with('JavaMain', kind_of(Logger)) do
        {}
      end
      JavaBuildpack::Util::JavaMainUtils.main_class('spec/fixtures/container_main').should eq('test-main-class')
    end

  end

end
