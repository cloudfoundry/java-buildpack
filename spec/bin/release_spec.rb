# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'integration_helper'

describe 'release script', :integration do # rubocop:disable RSpec/DescribeClass
  include_context 'integration_helper'

  it 'returns zero if success',
     app_fixture: 'integration_valid' do

    run("bin/release #{app_dir}") { |status| expect(status).to be_success }
  end

  it 'fails to release when no containers detect' do
    run("bin/release #{app_dir}") do |status|
      expect(status).not_to be_success
      expect(stderr.string).to match(/No container can run this application/)
    end
  end

  it 'add default command line environment as expected',
     app_fixture: 'integration_valid' do

    run("bin/release #{app_dir}") do |status|
      expect(status).to be_success
      expect(YAML.load(stdout.string)['default_process_types']['web']).to match(/.* MALLOC_ARENA_MAX=2 .*/)
    end
  end

  it 'allow disabling malloc tuning',
     app_fixture: 'integration_valid' do

    ENV['JBP_NO_MALLOC_TUNING'] = '1'
    run("bin/release #{app_dir}") do |status|
      expect(status).to be_success
      expect(YAML.load(stdout.string)['default_process_types']['web']).not_to match(/.* MALLOC_ARENA_MAX.*/)
    end
  end

  it 'do malloc tuning when JBP_NO_MALLOC_TUNING=0',
     app_fixture: 'integration_valid' do

    ENV['JBP_NO_MALLOC_TUNING'] = '0'
    run("bin/release #{app_dir}") do |status|
      expect(status).to be_success
      expect(YAML.load(stdout.string)['default_process_types']['web']).to match(/.* MALLOC_ARENA_MAX=2 .*/)
    end
  end

  it 'when env contains value, don\'t include it to the command line',
     app_fixture: 'integration_valid' do

    ENV['MALLOC_ARENA_MAX'] = '4'
    run("bin/release #{app_dir}") do |status|
      expect(status).to be_success
      expect(YAML.load(stdout.string)['default_process_types']['web']).not_to match(/.* MALLOC_ARENA_MAX.*/)
    end
  end
end
