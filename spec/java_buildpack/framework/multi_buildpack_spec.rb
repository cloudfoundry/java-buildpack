# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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

require 'pathname'
require 'spec_helper'
require 'component_helper'
require 'java_buildpack/framework/multi_buildpack'

describe JavaBuildpack::Framework::MultiBuildpack do
  include_context 'with component help'

  let(:dep_dirs) do
    Dir.mktmpdir
    ret = []
    [1, 2, 3].each do |_|
      ret.push dep_dir
    end
    ret
  end

  def dep_dir
    ddirpath = Dir.mktmpdir + '/deps'
    Dir.mkdir(ddirpath, 0o0755)
    Pathname.new ddirpath
  end

  before do |example|
    app_fixture = example.metadata[:app_fixture]
    if app_fixture
      (0..2).each do |i|
        FileUtils.cp_r "spec/fixtures/#{app_fixture.chomp}/#{i}/.", dep_dirs[i] if dep_dirs[i]
      end
    end

    allow(Pathname).to receive(:glob).with('/tmp/*/deps').and_return(dep_dirs)
  end

  it 'does not detect without deps' do
    expect(component.detect).to be_nil
  end

  it 'detects when deps with config.yml exist',
     app_fixture: 'framework_multi_buildpack_deps' do

    expect(component.detect).to include('test-buildpack-0-0',
                                        'test-buildpack-0-2', 'test-buildpack-1-0',
                                        'test-buildpack-1-2', 'test-buildpack-2-0',
                                        'test-buildpack-2-2')
  end

  it 'adds bin/ directory to $PATH during compile if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(environment_variables).to include('PATH=$PATH:$PWD/../deps/0/bin')
  end

  it 'adds bin/ directory to $PATH during release if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(environment_variables).to include('PATH=$PATH:$PWD/../deps/0/bin')
  end

  it 'adds lib/ directory to $LD_LIBRARY_PATH during compile if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(environment_variables).to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/../deps/0/lib')
  end

  it 'adds lib/ directory to $LD_LIBRARY_PATH during release if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(environment_variables).to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/../deps/0/lib')
  end

  it 'adds additional_libraries during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(additional_libraries).to include(Pathname.new('/multi-test-additional-library-1'))
    expect(additional_libraries).to include(Pathname.new('/multi-test-additional-library-2'))
  end

  it 'adds additional_libraries during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(additional_libraries).to include(Pathname.new('/multi-test-additional-library-1'))
    expect(additional_libraries).to include(Pathname.new('/multi-test-additional-library-2'))
  end

  it 'adds agentpaths during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-1')}")
    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-2')}")
  end

  it 'adds agentpaths during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-1')}")
    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-2')}")
  end

  it 'adds agentpaths_with_props during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-1')}=" \
                                 'test-key-1=test-value-1,test-key-2=test-value-2')
    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-2')}=" \
                                 'test-key-1=test-value-1,test-key-2=test-value-2')
  end

  it 'adds agentpaths_with_props during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-1')}=" \
                                 'test-key-1=test-value-1,test-key-2=test-value-2')
    expect(java_opts).to include("-agentpath:$PWD/#{qualify_path('/multi-test-agent-2')}=" \
                                 'test-key-1=test-value-1,test-key-2=test-value-2')
  end

  it 'adds bootclasspath_ps during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include("-Xbootclasspath/p:$PWD/#{qualify_path('/multi-test-bootclasspath-p-1')}")
    expect(java_opts).to include("-Xbootclasspath/p:$PWD/#{qualify_path('/multi-test-bootclasspath-p-2')}")
  end

  it 'adds bootclasspath_ps during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include("-Xbootclasspath/p:$PWD/#{qualify_path('/multi-test-bootclasspath-p-1')}")
    expect(java_opts).to include("-Xbootclasspath/p:$PWD/#{qualify_path('/multi-test-bootclasspath-p-2')}")
  end

  it 'adds environment_variables during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(environment_variables).to include('multi-test-key-1=multi-test-value-1')
    expect(environment_variables).to include('multi-test-key-2=multi-test-value-2')
  end

  it 'adds environment_variables during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(environment_variables).to include('multi-test-key-1=multi-test-value-1')
    expect(environment_variables).to include('multi-test-key-2=multi-test-value-2')
  end

  it 'adds extension_directories during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(extension_directories).to include(Pathname.new('/multi-test-extension-directory-1'))
    expect(extension_directories).to include(Pathname.new('/multi-test-extension-directory-2'))
  end

  it 'adds extension_directories during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(extension_directories).to include(Pathname.new('/multi-test-extension-directory-1'))
    expect(extension_directories).to include(Pathname.new('/multi-test-extension-directory-2'))
  end

  it 'adds javaagents during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include("-javaagent:$PWD/#{qualify_path('/multi-test-java-agent-1')}")
    expect(java_opts).to include("-javaagent:$PWD/#{qualify_path('/multi-test-java-agent-2')}")
  end

  it 'adds javaagents during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include("-javaagent:$PWD/#{qualify_path('/multi-test-java-agent-1')}")
    expect(java_opts).to include("-javaagent:$PWD/#{qualify_path('/multi-test-java-agent-2')}")
  end

  it 'adds options during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include('multi-test-key-1=multi-test-value-1')
    expect(java_opts).to include('multi-test-key-2=multi-test-value-2')
  end

  it 'adds options during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include('multi-test-key-1=multi-test-value-1')
    expect(java_opts).to include('multi-test-key-2=multi-test-value-2')
  end

  it 'adds preformatted_options during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include('multi-test-preformatted-option-1')
    expect(java_opts).to include('multi-test-preformatted-option-2')
  end

  it 'adds preformatted_options during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include('multi-test-preformatted-option-1')
    expect(java_opts).to include('multi-test-preformatted-option-2')
  end

  it 'adds security_providers during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(security_providers).to include('multi-test-security-provider-1')
    expect(security_providers).to include('multi-test-security-provider-2')
  end

  it 'adds security_providers during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(security_providers).to include('multi-test-security-provider-1')
    expect(security_providers).to include('multi-test-security-provider-2')
  end

  it 'adds system_properties during compile',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(java_opts).to include('-Dmulti-test-key-1=multi-test-value-1')
    expect(java_opts).to include('-Dmulti-test-key-2=multi-test-value-2')
  end

  it 'adds system_properties during release',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(java_opts).to include('-Dmulti-test-key-1=multi-test-value-1')
    expect(java_opts).to include('-Dmulti-test-key-2=multi-test-value-2')
  end

  def qualify_path(path)
    Pathname.new(path).relative_path_from(application.root)
  end

end
