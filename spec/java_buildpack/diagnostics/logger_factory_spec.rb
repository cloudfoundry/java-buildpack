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
require 'java_buildpack/diagnostics/logger_factory'

module JavaBuildpack::Diagnostics

  describe LoggerFactory do

    LOG_MESSAGE = 'a log message'

    before do
      JavaBuildpack::Diagnostics::LoggerFactory.send :close
      $stderr = StringIO.new
      tmpdir = Dir.tmpdir
      diagnostics_directory = File.join(tmpdir, JavaBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY)
      FileUtils.rm_rf diagnostics_directory
      JavaBuildpack::Diagnostics::LoggerFactory.create_logger tmpdir
    end

    it 'should create a logger' do
      Dir.mktmpdir do |app_dir|
        logger = new_logger app_dir
        expect(logger).to_not be_nil
      end
    end

    it 'should act as a singleton' do
      Dir.mktmpdir do |app_dir|
        initial_logger = new_logger app_dir
        logger = LoggerFactory.get_logger
        expect(logger).to equal(initial_logger)
        expect(LoggerFactory.get_logger).to equal(logger)
      end
    end

    it 'should send debug logs to standard output when debug is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('DEBUG') do
          logger = new_logger app_dir
          logger.debug { LOG_MESSAGE }
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should not send debug logs to standard output when debug is disabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('INFO') do
          logger = new_logger app_dir
          logger.debug { LOG_MESSAGE }
          expect($stderr.string).to_not match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should send info logs to standard output when info is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('info') do
          logger = new_logger app_dir
          logger.info(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should not send info logs to standard output when info is disabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('WARN') do
          logger = new_logger app_dir
          logger.info(LOG_MESSAGE)
          expect($stderr.string).to_not match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should send warn logs to standard error when warn is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('warn') do
          logger = new_logger app_dir
          logger.warn(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should not send warn logs to standard error when warn is disabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('ERROR') do
          logger = new_logger app_dir
          logger.info(LOG_MESSAGE)
          expect($stderr.string).to_not match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should send error logs to standard error when error is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('ERROR') do
          logger = new_logger app_dir
          logger.error(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should not send error logs to standard error when error is disabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('FATAL') do
          logger = new_logger app_dir
          logger.error(LOG_MESSAGE)
          expect($stderr.string).to_not match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should send fatal logs to standard error when fatal is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('FATAL') do
          logger = new_logger app_dir
          logger.fatal(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should send debug logs to standard output when an unknown log level is specified' do
      Dir.mktmpdir do |app_dir|
        with_log_level('XXX') do
          logger = new_logger app_dir
          logger.debug(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    it 'should take the default log level from a YAML file' do
      YAML.stub(:load_file).with(File.expand_path('config/logging.yml')).and_return(
          'default_log_level' => 'DEBUG')
      begin
        Dir.mktmpdir do |app_dir|
          logger = new_logger app_dir
          logger.debug(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        end
      ensure
        YAML.stub(:load_file).with(File.expand_path('config/logging.yml')).and_return(
            'default_log_level' => 'INFO')
      end
    end

    it 'should warn if the logger is closed' do
      Dir.mktmpdir do |app_dir|
        with_log_level('WARN') do
          logger = new_logger app_dir
          logger.close
          expect($stderr.string).to match(/logger is being closed/)
        end
      end
    end

    it 'should log the calling method name when Logger.add is not called' do
      Dir.mktmpdir do |app_dir|
        logger = new_logger app_dir
        info_method_caller logger
        expect($stderr.string).to match(/info_method_caller/)
      end
    end

    it 'should log the calling method name when Logger.add is called' do
      Dir.mktmpdir do |app_dir|
        logger = new_logger app_dir
        add_method_caller logger
        expect($stderr.string).to match(/add_method_caller/)
      end
    end

    it 'should fail if a LoggerFactory is constructed' do
      expect { LoggerFactory.new }.to raise_error(/private method `new'/)
    end

    it 'should send debug logs to standard output when $VERBOSE is true' do
      Dir.mktmpdir do |app_dir|
        previous_value = $VERBOSE
        begin
          $VERBOSE = true
          logger = new_logger app_dir
          logger.debug(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        ensure
          $VERBOSE = previous_value
        end
      end
    end

    it 'should send debug logs to standard output when $DEBUG is true' do
      Dir.mktmpdir do |app_dir|
        previous_value = $DEBUG
        begin
          $DEBUG = true
          logger = new_logger app_dir
          logger.debug(LOG_MESSAGE)
          expect($stderr.string).to match(/#{LOG_MESSAGE}/)
        ensure
          $DEBUG = previous_value
        end
      end
    end

    it 'should send info logs to buildpack.log when info is enabled' do
      Dir.mktmpdir do |app_dir|
        with_log_level('info') do
          logger = new_logger app_dir
          logger.info(LOG_MESSAGE)
          file_contents = File.read File.join(JavaBuildpack::Diagnostics.get_diagnostic_directory(app_dir), JavaBuildpack::Diagnostics::LOG_FILE_NAME)
          expect(file_contents).to match(/#{LOG_MESSAGE}/)
        end
      end
    end

    def new_logger(app_dir)
      LoggerFactory.send :close # suppress warnings
      LoggerFactory.create_logger app_dir
    end

    def with_log_level(log_level)
      previous_value = ENV['JBP_LOG_LEVEL']
      begin
        ENV['JBP_LOG_LEVEL'] = log_level
        yield
      ensure
        ENV['JBP_LOG_LEVEL'] = previous_value
      end
    end

    def info_method_caller(logger)
      logger.info(LOG_MESSAGE)
    end

    def add_method_caller(logger)
      logger.add(::Logger::INFO, LOG_MESSAGE)
    end

  end

end