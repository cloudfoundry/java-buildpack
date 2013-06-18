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
require 'java_buildpack/container/tomcat'

module JavaBuildpack::Container

  describe Tomcat do

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(JavaBuildpack::Util::TokenizedVersion.new('7.0.40')).and_return('resolved-version', 'test-uri')
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect

      expect(detected).to eq('tomcat-resolved-version')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_none',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

    it 'should fail when a malformed version is detected' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_yield(JavaBuildpack::Util::TokenizedVersion.new('7.0.40_0')).and_return('resolved-version', 'test-uri')
      expect { Tomcat.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect }.to raise_error(/Malformed\ Tomcat\ version/)
    end

  end

end
