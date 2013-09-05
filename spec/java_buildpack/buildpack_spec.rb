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
require 'java_buildpack/buildpack'
require 'java_buildpack/diagnostics/logger_factory'

module JavaBuildpack

  APP_DIR = 'test-app-dir'.freeze

  describe Buildpack do

    let(:stub_container1) { double('StubContainer1', detect: nil) }
    let(:stub_container2) { double('StubContainer2', detect: nil) }
    let(:stub_framework1) { double('StubFramework1', detect: nil) }
    let(:stub_framework2) { double('StubFramework2', detect: nil) }
    let(:stub_jre1) { double('StubJre1', detect: nil) }
    let(:stub_jre2) { double('StubJre2', detect: nil) }

    before do
      YAML.stub(:load_file).with(File.expand_path('config/logging.yml')).and_return(
          'default_log_level' => 'DEBUG'
      )
      YAML.stub(:load_file).with(File.expand_path('config/components.yml')).and_return(
          'containers' => ['Test::StubContainer1', 'Test::StubContainer2'],
          'frameworks' => ['Test::StubFramework1', 'Test::StubFramework2'],
          'jres' => ['Test::StubJre1', 'Test::StubJre2']
      )

      Test::StubContainer1.stub(:new).and_return(stub_container1)
      Test::StubContainer2.stub(:new).and_return(stub_container2)

      Test::StubFramework1.stub(:new).and_return(stub_framework1)
      Test::StubFramework2.stub(:new).and_return(stub_framework2)

      Test::StubJre1.stub(:new).and_return(stub_jre1)
      Test::StubJre2.stub(:new).and_return(stub_jre2)

      JavaBuildpack::Diagnostics::LoggerFactory.send :close
      $stderr = StringIO.new
      tmpdir = Dir.tmpdir
      diagnostics_directory = File.join(tmpdir, JavaBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
      FileUtils.rm_rf diagnostics_directory
      JavaBuildpack::Diagnostics::LoggerFactory.create_logger tmpdir
    end

    it 'should raise an error if more than one container can run an application' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_container2.stub(:detect).and_return('stub-container-2')

      with_buildpack { |buildpack| expect { buildpack.detect }.to raise_error(/stub-container-1, stub-container-2/) }
    end

    it 'should return no detections if no container can run an application' do
      detected = with_buildpack { |buildpack| buildpack.detect }
      expect(detected).to be_empty
    end

    it 'should raise an error on compile if no container can run an application' do
      with_buildpack { |buildpack| expect { buildpack.compile }.to raise_error(/No supported application type/) }
    end

    it 'should raise an error on release if no container can run an application' do
      with_buildpack { |buildpack| expect { buildpack.release }.to raise_error(/No supported application type/) }
    end

    it 'should raise an error if more than one JRE can run an application' do
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      stub_jre2.stub(:detect).and_return('stub-jre-2')

      with_buildpack { |buildpack| expect { buildpack.detect }.to raise_error(/stub-jre-1, stub-jre-2/) }
    end

    it 'should call compile on matched components' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_framework1.stub(:detect).and_return('stub-framework-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')

      stub_container1.should_receive(:compile)
      stub_container2.should_not_receive(:compile)
      stub_framework1.should_receive(:compile)
      stub_framework2.should_not_receive(:compile)
      stub_jre1.should_receive(:compile)
      stub_jre2.should_not_receive(:compile)

      with_buildpack { |buildpack| buildpack.compile }
    end

    it 'should call release on matched components' do
      stub_container1.stub(:detect).and_return('stub-container-1')
      stub_framework1.stub(:detect).and_return('stub-framework-1')
      stub_jre1.stub(:detect).and_return('stub-jre-1')

      stub_container1.stub(:release).and_return('test-command')

      stub_container1.should_receive(:release)
      stub_container2.should_not_receive(:release)
      stub_framework1.should_receive(:release)
      stub_framework2.should_not_receive(:release)
      stub_jre1.should_receive(:release)
      stub_jre2.should_not_receive(:release)

      payload = with_buildpack { |buildpack| buildpack.release }

      expect(payload).to eq({ 'addons' => [], 'config_vars' => {}, 'default_process_types' => { 'web' => 'test-command' } }.to_yaml)
    end

    it 'should load configuration file matching JRE class name' do
      stub_jre1.stub(:detect).and_return('stub-jre-1')
      File.stub(:exists?).with(File.expand_path('config/stubjre1.yml')).and_return(true)
      File.stub(:exists?).with(File.expand_path('config/stubjre2.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubframework1.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubframework2.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubcontainer1.yml')).and_return(false)
      File.stub(:exists?).with(File.expand_path('config/stubcontainer2.yml')).and_return(false)
      YAML.stub(:load_file).with(File.expand_path('config/stubjre1.yml')).and_return('x' => 'y')

      with_buildpack { |buildpack| buildpack.detect }
    end

    it 'logs information about the git repository of a buildpack' do
      with_buildpack { |buildpack| buildpack.detect }
      standard_error = $stderr.string
      expect(standard_error).to match(/git remotes/)
      expect(standard_error).to match(/git HEAD commit/)
    end

    it 'realises when buildpack is not stored in a git repository' do
      Dir.mktmpdir do |tmp_dir|
        Buildpack.stub(:git_dir).and_return(tmp_dir)
        with_buildpack { |buildpack| buildpack.detect }
        expect($stderr.string).to match(/Buildpack is not stored in a git repository/)
      end
    end

    it 'handles exceptions correctly' do
      expect { with_buildpack { |buildpack| raise 'an exception' } }.to raise_error SystemExit
      expect($stderr.string).to match(/an exception/)
    end

    def with_buildpack(&block)
      JavaBuildpack::Diagnostics::LoggerFactory.send :close # suppress warnings
      Dir.mktmpdir do |root|
        Buildpack.drive_buildpack_with_logger(File.join(root, APP_DIR), 'Error %s') do |buildpack|
          block.call buildpack
        end
      end
    end

  end

end

module Test
  class StubContainer1
  end

  class StubContainer2
  end

  class StubJre1
  end

  class StubJre2
  end

  class StubFramework1
  end

  class StubFramework2
  end
end
