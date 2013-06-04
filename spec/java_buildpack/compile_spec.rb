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
require 'tmpdir'

describe JavaBuildpack::Compile do

  let(:application_cache) { double('ApplicationCache') }
  let(:jre_selector) { double('JreSelector', :id => 'test-id', :vendor => 'test-vendor', :version => 'test-version', :uri => 'test-uri') }

  before do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  it 'should extract Java from a GZipped TAR' do
    Dir.mktmpdir do |root|
      JavaBuildpack::JreProperties.stub(:new).with(root).and_return(jre_selector)
      JavaBuildpack::ApplicationCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('test-id', 'test-uri').and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

      JavaBuildpack::Compile.new(root).run

      java = File.join(root, '.java', 'bin', 'java')
      expect(File.exists?(java)).to be_true
    end
  end

end
