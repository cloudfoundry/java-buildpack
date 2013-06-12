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

  RSpec.configure do |c|
    c.filter_run_excluding :waiting_for_memory_limit_support => true
  end

  describe OpenJdk, :waiting_for_memory_limit_support => true do

    HEAP_SIZE = '1G'

    INVALID_HEAP_SIZE = '1024M -Xint'

    PERMGEN_SIZE = '128M'

    METASPACE_SIZE = '128M'

    INVALID_PERMGEN_SIZE = '128M -Xint'

    STACK_SIZE = '128K'

    INVALID_STACK_SIZE = '128K -Xint'

    let(:application_cache) { double('ApplicationCache') }
    let(:details_pre_8) { double('Details', :vendor => 'test-vendor', :version => '1.7', :uri => 'test-uri') }
    let(:details_post_8) { double('Details', :vendor => 'test-vendor', :version => '1.8', :uri => 'test-uri') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of JRE' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        detected = OpenJdk.new(:configuration => {}, :java_opts => []).detect

        expect(detected).to eq('jre-test-vendor-1.7')
      end
    end

    it 'should extract Java from a GZipped TAR' do
      with_memory_limit('1G') do
        Dir.mktmpdir do |root|
          Details.stub(:new).and_return(details_pre_8)
          JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
          application_cache.stub(:get).with('jre-test-vendor-1.7', 'test-uri')
          .and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

          OpenJdk.new(:app_dir => root, :configuration => {}, :java_opts => []).compile

          java = File.join(root, '.java', 'bin', 'java')
          expect(File.exists?(java)).to be_true
        end
      end
    end

    it 'adds the resolved heap size to java_opts' do
      with_memory_limit('2G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {'java.heap.size' => HEAP_SIZE}).release

        expect(java_opts[0]).to eq("-Xmx#{HEAP_SIZE}")
      end
    end

    it 'adds a default heap size to java_opts if not specified' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {}).release

        expect(java_opts[0]).to match(/-Xmx/)
      end
    end

    it 'raises an error when heap size has embedded whitespace' do
      Details.stub(:new).and_return(details_pre_8)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :configuration => {'java.heap.size' => INVALID_HEAP_SIZE}).release }.to raise_error
    end

    it 'adds the resolved permgen size to java_opts' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {'java.permgen.size' => PERMGEN_SIZE}).release

        expect(java_opts[2]).to eq("-XX:MaxPermSize=#{PERMGEN_SIZE}")
      end
    end

    it 'adds a default permgen size to java_opts if not specified' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {}).release

        expect(java_opts[2]).to match(/-XX:MaxPermSize=/)
      end
    end

    it 'raises an error when permgen size has embedded whitespace' do
      Details.stub(:new).and_return(details_pre_8)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :configuration => {'java.permgen.size' => INVALID_PERMGEN_SIZE}).release }.to raise_error
    end

    it 'adds the resolved stack size to java_opts' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {'java.stack.size' => STACK_SIZE}).release

        expect(java_opts[1]).to eq("-Xss#{STACK_SIZE}")
      end
    end

    it 'does not add a stack size to java_opts if not specified' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_pre_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {}).release

        expect(java_opts[1]).to match(/-Xss/)
      end
    end

    it 'raises an error when stack size has embedded whitespace' do
      Details.stub(:new).and_return(details_pre_8)

      java_opts = []
      expect { OpenJdk.new(:java_opts => java_opts, :configuration => {'java.stack.size' => INVALID_STACK_SIZE}).release }.to raise_error
    end

    it 'adds the resolved maximum metaspace size to java_opts' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_post_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {'java.metaspace.size' => METASPACE_SIZE}).release

        expect(java_opts[2]).to eq("-XX:MaxMetaspaceSize=#{PERMGEN_SIZE}")
      end
    end

    it 'adds a default permgen size to java_opts if not specified' do
      with_memory_limit('1G') do
        Details.stub(:new).and_return(details_post_8)

        java_opts = []
        OpenJdk.new(:java_opts => java_opts, :configuration => {}).release

        expect(java_opts[2]).to match(/-XX:MaxMetaspaceSize=/)
      end
    end

    def with_memory_limit(memory_limit)
      previous_value = ENV['MEMORY_LIMIT']
      begin
        ENV['MEMORY_LIMIT'] = memory_limit
        yield
      ensure
        ENV['MEMORY_LIMIT'] = previous_value
      end
    end

  end

end
