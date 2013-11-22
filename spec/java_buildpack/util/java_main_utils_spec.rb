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
require 'diagnostics_helper'
require 'logger'
require 'java_buildpack/buildpack'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack::Util

  describe JavaMainUtils do
    include_context 'diagnostics_helper'

    let(:test_class_name) { 'test-java-main-class' }

    it 'should use a main class configuration in a configuration file' do
      allow(JavaBuildpack::Buildpack).to receive(:configuration).with('JavaMain', kind_of(Logger))
                                         .and_return('java_main_class' => test_class_name)

      expect(JavaMainUtils.main_class('')).to eq(test_class_name)
    end

    it 'should use a main class configuration in a configuration parameter' do
      expect(JavaMainUtils.main_class('', 'java_main_class' => test_class_name)).to eq(test_class_name)
    end

    it 'should use a main class in the manifest of the application' do
      allow(JavaBuildpack::Buildpack).to receive(:configuration).with('JavaMain', kind_of(Logger)).and_return({})

      expect(JavaMainUtils.main_class('spec/fixtures/container_main')).to eq('test-main-class')
    end

  end

end
