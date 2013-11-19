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

require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'webmock/rspec'
WebMock.disable_net_connect!(allow: 'codeclimate.com')

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
