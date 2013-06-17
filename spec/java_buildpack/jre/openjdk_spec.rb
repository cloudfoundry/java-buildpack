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

    HEAP_SIZE = '1G'

    INVALID_HEAP_SIZE = '1024M -Xint'

    PERMGEN_SIZE = '128M'

    METASPACE_SIZE = '128M'

    INVALID_PERMGEN_SIZE = '128M -Xint'

    STACK_SIZE = '128K'

    INVALID_STACK_SIZE = '128K -Xint'

    BASE_CONFIGURATION = {
      'repository_root' => 'test-repository-root',
      'memory_heuristics' => {
        'post_8' => {
          'heap' => 0.75,
          'metaspace' => 0.1,
          'stack' => 0.05,
          'native' => 0.1
        },
        'pre_8' => {
          'heap' => 0.75,
          'permgen' => 0.1,
          'stack' => 0.05,
          'native' => 0.1
        }
      }
    }.freeze

    DETAILS_PRE_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.7.0'), 'test-uri']
    DETAILS_POST_8 = [JavaBuildpack::Util::TokenizedVersion.new('1.8.0'), 'test-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect with id of JRE' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        detected = OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => [],
          :configuration => BASE_CONFIGURATION
        ).detect

        expect(detected).to eq('openjdk-1.7.0')
      end
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)
        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-uri').and_yield(File.open('spec/fixtures/stub-java.tar.gz'))

        OpenJdk.new(
          :app_dir => root,
          :configuration => BASE_CONFIGURATION,
          :java_home => '',
          :java_opts => []
        ).compile

        java = File.join(root, '.java', 'bin', 'java')
        expect(File.exists?(java)).to be_true
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      with_memory_limit('2G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_home = ''
        OpenJdk.new(
          :app_dir => '/application-directory',
          :java_home => java_home,
          :java_opts => [],
          :configuration => BASE_CONFIGURATION
        )

        expect(java_home).to eq(File.join('/application-directory', '.java'))
      end
    end

    it 'adds the resolved heap size to java_opts' do
      with_memory_limit('2G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION.merge({'java.heap.size' => HEAP_SIZE})
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-Xmx#{HEAP_SIZE}/)
      end
    end

    it 'adds a default heap size to java_opts if not specified' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-Xmx/)
      end
    end

    it 'raises an error when heap size has embedded whitespace' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

      java_opts = []
      expect { OpenJdk.new(
        :app_dir => '',
        :java_home => '',
        :java_opts => java_opts,
        :configuration => BASE_CONFIGURATION.merge({'java.heap.size' => INVALID_HEAP_SIZE})
      ).release }.to raise_error
    end

    it 'adds the resolved permgen size to java_opts' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION.merge({'java.permgen.size' => PERMGEN_SIZE})
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-XX:MaxPermSize=#{PERMGEN_SIZE}/)
      end
    end

    it 'adds a default permgen size to java_opts if not specified' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-XX:MaxPermSize=/)
      end
    end

    it 'raises an error when permgen size has embedded whitespace' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

      java_opts = []
      expect { OpenJdk.new(
        :app_dir => '',
        :java_home => '',
        :java_opts => java_opts,
        :configuration => BASE_CONFIGURATION.merge({'java.permgen.size' => INVALID_PERMGEN_SIZE})
      ).release }.to raise_error
    end

    it 'adds the resolved stack size to java_opts' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION.merge({'java.stack.size' => STACK_SIZE})
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-Xss#{STACK_SIZE}/)
      end
    end

    it 'adds a stack size to java_opts if not specified' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-Xss1M/)
      end
    end

    it 'raises an error when stack size has embedded whitespace' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

      java_opts = []
      expect { OpenJdk.new(
        :app_dir => '',
        :java_home => '',
        :java_opts => java_opts,
        :configuration => {'java.stack.size' => INVALID_STACK_SIZE}
      ).release }.to raise_error
    end

    it 'adds the resolved maximum metaspace size to java_opts' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_POST_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION.merge({'java.metaspace.size' => METASPACE_SIZE})
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-XX:MaxMetaspaceSize=#{PERMGEN_SIZE}/)
      end
    end

    it 'adds a default permgen size to java_opts if not specified' do
      with_memory_limit('1G') do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_POST_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION
        ).release

        expect(java_opts.length).to eq(3)
        expect(java_opts.join(' ')).to match(/-XX:MaxMetaspaceSize=/)
      end
    end

    it 'falls back to not defaulting memory sizes if $MEMORY_LIMIT is not set' do
      with_memory_limit(nil) do
        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(DETAILS_PRE_8)

        java_opts = []
        OpenJdk.new(
          :app_dir => '',
          :java_home => '',
          :java_opts => java_opts,
          :configuration => BASE_CONFIGURATION
        ).release

        expect(java_opts.length).to eq(1)
        expect(java_opts[0]).to match(/-Xss1M/)
      end
    end

    it 'should fail when ConfiguredItem.find_item fails' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item).and_raise('test error')
      expect { OpenJdk.new(
        :app_dir => '',
        :java_home => '',
        :java_opts => [],
        :configuration => BASE_CONFIGURATION
      ).detect }.to raise_error(/OpenJDK\ JRE\ error:\ test\ error/)
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
