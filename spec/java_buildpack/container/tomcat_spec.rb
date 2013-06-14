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

  let(:tomcat_details) { double('TomcatDetails', :configured_version => JavaBuildpack::Util::TokenizedVersion.new('7.0.40'), :uri => 'test-uri') }

    it 'should detect WEB-INF' do
      TomcatDetails.stub(:new).and_return(tomcat_details)
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_tomcat',
          :configuration => {}).detect

      expect(detected).to eq('tomcat-7.0.40')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Tomcat.new(
          :app_dir => 'spec/fixtures/container_none',
          :configuration => {}).detect

      expect(detected).to be_nil
    end

  end

end
