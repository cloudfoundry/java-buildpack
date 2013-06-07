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
require 'java_buildpack/jre/openjdk'
require 'tmpdir'

module JavaBuildpack::Jre

  describe OpenJdk do

    HEAP_SIZE = '1024m'

    INVALID_HEAP_SIZE = '1024m -Xint'

    PERMGEN_SIZE = '128m'

    INVALID_PERMGEN_SIZE = '128m -Xint'

    STACK_SIZE = '128k'

    INVALID_STACK_SIZE = '128k -Xint'

    let(:application_cache) { double('ApplicationCache') }
    let(:details) { double('Details', :vendor => 'test-vendor', :version => 'test-version', :uri => 'test-uri') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of JRE' do
      Details.stub(:new).and_return(details)

      detected = OpenJdk.new().detect

      expect(detected).to eq('jre-test-vendor-test-version')
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        Details.stub(:new).and_return(details)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('jre-test-vendor-test-version', 'test-uri')
          .and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

        OpenJdk.new(:app_dir => root).compile

        java = File.join(root, '.java', 'bin', 'java')
        expect(File.exists?(java)).to be_true
      end
    end

    it 'adds the resolved heap size to java_opts' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.heap.size' => HEAP_SIZE }).release

      expect(java_opts[0]).to eq("-Xmx#{HEAP_SIZE}")
    end

    it 'does not add a heap size to java_opts if not specified' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => {}).release

      expect(java_opts[0]).to be_nil
    end

      it 'raises an error when heap size has embedded whitespace' do
      Details.stub(:new).and_return(details)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.heap.size' => INVALID_HEAP_SIZE }).release}.to raise_error
    end

    it 'adds the resolved permgen size to java_opts' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.permgen.size' => PERMGEN_SIZE }).release

      expect(java_opts[1]).to eq("-XX:MaxPermSize=#{PERMGEN_SIZE}")
    end

    it 'does not add a permgen size to java_opts if not specified' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => {}).release

      expect(java_opts[1]).to be_nil
    end

      it 'raises an error when permgen size has embedded whitespace' do
      Details.stub(:new).and_return(details)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.permgen.size' => INVALID_PERMGEN_SIZE }).release}.to raise_error
    end

    it 'adds the resolved stack size to java_opts' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.stack.size' => STACK_SIZE }).release

      expect(java_opts[2]).to eq("-Xss#{STACK_SIZE}")
    end

    it 'does not add a stack size to java_opts if not specified' do
      Details.stub(:new).and_return(details)

      java_opts = []
      OpenJdk.new(:java_opts => java_opts, :system_properties => {}).release

      expect(java_opts[2]).to be_nil
    end

      it 'raises an error when stack size has embedded whitespace' do
      Details.stub(:new).and_return(details)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :system_properties => { 'java.stack.size' => INVALID_STACK_SIZE }).release}.to raise_error
    end
  end

end
