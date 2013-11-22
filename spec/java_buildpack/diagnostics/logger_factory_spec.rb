# Encoding: utf-8
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
require 'console_helper'
require 'diagnostics_helper'
require 'java_buildpack/diagnostics'
require 'java_buildpack/diagnostics/logger_factory'
require 'yaml'

module JavaBuildpack::Diagnostics

  describe LoggerFactory do
    include_context 'console_helper'
    include_context 'diagnostics_helper'

    let(:log_message) { 'a log message' }

    it 'should create a logger' do
      expect(logger).not_to be_nil
    end

    it 'should act as a singleton' do
      expect(LoggerFactory.get_logger).to equal(logger)
      expect(LoggerFactory.get_logger).to equal(LoggerFactory.get_logger)
    end

    it 'should send debug logs to standard output when debug is enabled',
       log_level: 'DEBUG' do

      logger.debug { log_message }
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should not send debug logs to standard output when debug is disabled',
       log_level: 'INFO' do

      logger.debug { log_message }
      expect(stderr.string).to_not match /#{log_message}/
    end

    it 'should send info logs to standard output when info is enabled',
       log_level: 'INFO' do

      logger.info(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should not send info logs to standard output when info is disabled',
       log_level: 'WARN' do

      logger.info(log_message)
      expect(stderr.string).to_not match /#{log_message}/
    end

    it 'should send warn logs to standard error when warn is enabled',
       log_level: 'WARN' do

      logger.warn(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should not send warn logs to standard error when warn is disabled',
       log_level: 'ERROR' do

      logger.info(log_message)
      expect(stderr.string).to_not match /#{log_message}/
    end

    it 'should send error logs to standard error when error is enabled',
       log_level: 'ERROR' do

      logger.error(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should not send error logs to standard error when error is disabled',
       log_level: 'FATAL' do

      logger.error(log_message)
      expect(stderr.string).to_not match /#{log_message}/
    end

    it 'should send fatal logs to standard error when fatal is enabled',
       log_level: 'FATAL' do

      logger.fatal(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should send debug logs to standard output when an unknown log level is specified',
       log_level: 'XXX' do

      logger.debug(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    context do

      before do
        allow(YAML).to receive(:load_file).with(File.expand_path('config/logging.yml'))
                       .and_return('default_log_level' => 'DEBUG')
      end

      it 'should take the default log level from a YAML file' do
        JavaBuildpack::Diagnostics::LoggerFactory.create_logger(app_dir).debug(log_message)
        expect(stderr.string).to match /#{log_message}/
      end
    end

    it 'should warn if the logger is closed',
       log_level: 'WARN' do

      logger.close
      expect(stderr.string).to match /logger is being closed/
    end

    it 'should log the calling method name when Logger.add is not called' do
      info_method_caller logger
      expect(stderr.string).to match /info_method_caller/
    end

    it 'should log the calling method name when Logger.add is called' do
      add_method_caller logger
      expect(stderr.string).to match /add_method_caller/
    end

    it 'should fail if a LoggerFactory is constructed' do
      expect { LoggerFactory.new }.to raise_error /private method `new'/
    end

    it 'should send debug logs to standard output when $VERBOSE is true',
       :verbose do

      logger.debug(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should send debug logs to standard output when $DEBUG is true',
       :debug do

      logger.debug(log_message)
      expect(stderr.string).to match /#{log_message}/
    end

    it 'should send info logs to buildpack.log when info is enabled',
       log_level: 'INFO' do

      logger.info(log_message)
      expect((diagnostics_dir + JavaBuildpack::Diagnostics::LOG_FILE_NAME).read).to match /#{log_message}/
    end

    it 'should issue warnings if the logger is re-created',
       log_level: 'WARN' do

      LoggerFactory.create_logger app_dir
      expect(stderr.string).to match /Logger is being re-created/
      expect(stderr.string).to match /Logger was re-created by/
    end

    context do

      previous_standard_error = nil

      before do
        previous_standard_error, STDERR = STDERR, stderr
        JavaBuildpack::Diagnostics::LoggerFactory.close
      end

      after do
        STDERR = previous_standard_error
      end

      it 'should fail if a non-existent logger is requested' do
        expect { LoggerFactory.get_logger }.to raise_error /no logger/
        expect(stderr.string).to match /Attempt to get nil logger from: /
      end

    end

    def info_method_caller(logger)
      logger.info(log_message)
    end

    def add_method_caller(logger)
      logger.add(::Logger::INFO, log_message)
    end

  end

end
