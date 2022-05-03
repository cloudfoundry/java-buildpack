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

require 'spec_helper'
require 'application_helper'
require 'console_helper'
require 'fileutils'
require 'java_buildpack/logging/logger_factory'
require 'yaml'

shared_context 'with logging help' do
  include_context 'with console help'
  include_context 'with application help'

  previous_log_config    = ENV.fetch('JBP_CONFIG_LOGGING', nil)
  previous_log_level     = ENV.fetch('JBP_LOG_LEVEL', nil)
  previous_debug_level   = $DEBUG
  previous_verbose_level = $VERBOSE

  let(:log_contents) { Pathname.new(app_dir + '.java-buildpack.log').read }

  before do |example|
    log_level            = example.metadata[:log_level]
    ENV['JBP_LOG_LEVEL'] = log_level if log_level

    enable_log_file           = example.metadata[:enable_log_file]
    ENV['JBP_CONFIG_LOGGING'] = { 'enable_log_file' => true }.to_yaml if enable_log_file

    $DEBUG   = example.metadata[:debug]
    $VERBOSE = example.metadata[:verbose]

    JavaBuildpack::Logging::LoggerFactory.instance.setup app_dir
  end

  after do
    JavaBuildpack::Logging::LoggerFactory.instance.reset

    ENV['JBP_CONFIG_LOGGING'] = previous_log_config
    ENV['JBP_LOG_LEVEL']      = previous_log_level
    $VERBOSE                  = previous_verbose_level
    $DEBUG                    = previous_debug_level
  end

end
