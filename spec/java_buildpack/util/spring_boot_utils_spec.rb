# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'droplet_helper'
require 'java_buildpack/util/spring_boot_utils'

describe JavaBuildpack::Util::SpringBootUtils do
  include_context 'droplet_helper'

  let(:utils) { described_class.new }

  it 'detects a dist Spring Boot application',
     app_fixture: 'container_spring_boot_dist' do

    expect(utils.is?(application)).to be
  end

  it 'detects a staged Spring Boot application',
     app_fixture: 'container_spring_boot_staged' do

    expect(utils.is?(application)).to be
  end

  it 'detects a JAR Spring Boot application',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    expect(utils.is?(application)).to be
  end

  it 'does not detect a non-Spring Boot application',
     app_fixture: 'container_main' do

    expect(utils.is?(application)).not_to be
  end

  it 'determines the version of a dist Spring Boot application',
     app_fixture: 'container_spring_boot_dist' do

    expect(utils.version(application)).to match(/1.0.0.RELEASE/)
  end

  it 'determines the version of a staged Spring Boot application',
     app_fixture: 'container_spring_boot_staged' do

    expect(utils.version(application)).to match(/1.0.0.RELEASE/)
  end

  it 'determines the version of a JAR Spring Boot application',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    expect(utils.version(application)).to match(/1.2.5.RELEASE/)
  end

  it 'returns BOOT-INF/lib as lib directory' do
    FileUtils.mkdir_p(app_dir + 'BOOT-INF/lib')

    expect(utils.lib(droplet)).to eq(droplet.root + 'BOOT-INF/lib')
  end

  it 'returns WEB-INF/lib as lib directory' do
    FileUtils.mkdir_p(app_dir + 'WEB-INF/lib')

    expect(utils.lib(droplet)).to eq(droplet.root + 'WEB-INF/lib')
  end

  it 'returns lib as lib directory' do
    FileUtils.mkdir_p(app_dir + 'lib')

    expect(utils.lib(droplet)).to eq(droplet.root + 'lib')
  end

  it 'returns manifest value as lib directory',
     app_fixture: 'container_main_spring_boot_jar_launcher' do

    FileUtils.mkdir_p(app_dir + 'manifest-lib-value')

    expect(utils.lib(droplet)).to eq(droplet.root + 'manifest-lib-value/')
  end

  it 'fails if there are no lib directories' do
    expect { utils.lib(droplet) }.to raise_error
  end

end
