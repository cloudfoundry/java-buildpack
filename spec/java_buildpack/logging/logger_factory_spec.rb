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
require 'logging_helper'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/configuration_utils'

describe JavaBuildpack::Logging::LoggerFactory do
  include_context 'console_helper'
  include_context 'logging_helper'

  let(:logger) { described_class.get_logger String }

  it 'should log all levels to file',
     log_level: 'FATAL' do

    trigger

    expect(log_contents).to match /DEBUG block-debug-message/
    expect(log_contents).to match /INFO  block-info-message/
    expect(log_contents).to match /WARN  block-warn-message/
    expect(log_contents).to match /ERROR block-error-message/
    expect(log_contents).to match /FATAL block-fatal-message/

    expect(log_contents).to match /DEBUG param-debug-message/
    expect(log_contents).to match /INFO  param-info-message/
    expect(log_contents).to match /WARN  param-warn-message/
    expect(log_contents).to match /ERROR param-error-message/
    expect(log_contents).to match /FATAL param-fatal-message/
  end

  it 'should log all levels to console when JBP_LOG_LEVEL set to DEBUG',
     log_level: 'DEBUG' do

    trigger

    expect(stderr.string).to match /DEBUG block-debug-message/
    expect(stderr.string).to match /INFO  block-info-message/
    expect(stderr.string).to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).to match /DEBUG param-debug-message/
    expect(stderr.string).to match /INFO  param-info-message/
    expect(stderr.string).to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/
  end

  it 'should log all levels above INFO to console when JBP_LOG_LEVEL set to INFO',
     log_level: 'INFO' do

    trigger

    expect(stderr.string).not_to match /DEBUG block-debug-message/
    expect(stderr.string).to match /INFO  block-info-message/
    expect(stderr.string).to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).not_to match /DEBUG param-debug-message/
    expect(stderr.string).to match /INFO  param-info-message/
    expect(stderr.string).to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/
  end

  it 'should log all levels above WARN to console when JBP_LOG_LEVEL set to WARN',
     log_level: 'WARN' do

    trigger

    expect(stderr.string).not_to match /DEBUG block-debug-message/
    expect(stderr.string).not_to match /INFO  block-info-message/
    expect(stderr.string).to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).not_to match /DEBUG param-debug-message/
    expect(stderr.string).not_to match /INFO  param-info-message/
    expect(stderr.string).to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/
  end

  it 'should log all levels above ERROR to console when JBP_LOG_LEVEL set to ERROR',
     log_level: 'ERROR' do

    trigger

    expect(stderr.string).not_to match /DEBUG block-debug-message/
    expect(stderr.string).not_to match /INFO  block-info-message/
    expect(stderr.string).not_to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).not_to match /DEBUG param-debug-message/
    expect(stderr.string).not_to match /INFO  param-info-message/
    expect(stderr.string).not_to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/
  end

  it 'should log FATAL to console when JBP_LOG_LEVEL set to FATAL',
     log_level: 'FATAL' do

    trigger

    expect(stderr.string).not_to match /DEBUG block-debug-message/
    expect(stderr.string).not_to match /INFO  block-info-message/
    expect(stderr.string).not_to match /WARN  block-warn-message/
    expect(stderr.string).not_to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).not_to match /DEBUG param-debug-message/
    expect(stderr.string).not_to match /INFO  param-info-message/
    expect(stderr.string).not_to match /WARN  param-warn-message/
    expect(stderr.string).not_to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/
  end

  it 'should log all levels to console when $DEBUG set',
     :debug do

    trigger

    expect(stderr.string).to match /DEBUG block-debug-message/
    expect(stderr.string).to match /INFO  block-info-message/
    expect(stderr.string).to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).to match /DEBUG param-debug-message/
    expect(stderr.string).to match /INFO  param-info-message/
    expect(stderr.string).to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/

  end

  it 'should log all levels to console when $VERBOSE set',
     :verbose do

    trigger

    expect(stderr.string).to match /DEBUG block-debug-message/
    expect(stderr.string).to match /INFO  block-info-message/
    expect(stderr.string).to match /WARN  block-warn-message/
    expect(stderr.string).to match /ERROR block-error-message/
    expect(stderr.string).to match /FATAL block-fatal-message/

    expect(stderr.string).to match /DEBUG param-debug-message/
    expect(stderr.string).to match /INFO  param-info-message/
    expect(stderr.string).to match /WARN  param-warn-message/
    expect(stderr.string).to match /ERROR param-error-message/
    expect(stderr.string).to match /FATAL param-fatal-message/

  end

  it 'should return the log file' do
    expect(described_class.log_file).to eq(app_dir + '.java-buildpack.log')
  end

  context do

    before do
      allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('logging', false)
                                                        .and_return('default_log_level' => 'DEBUG')
      described_class.reset
      described_class.setup app_dir
    end

    it 'should log all levels to console when default_log_level set to DEBUG in configuration file' do
      trigger

      expect(stderr.string).to match /DEBUG block-debug-message/
      expect(stderr.string).to match /INFO  block-info-message/
      expect(stderr.string).to match /WARN  block-warn-message/
      expect(stderr.string).to match /ERROR block-error-message/
      expect(stderr.string).to match /FATAL block-fatal-message/

      expect(stderr.string).to match /DEBUG param-debug-message/
      expect(stderr.string).to match /INFO  param-info-message/
      expect(stderr.string).to match /WARN  param-warn-message/
      expect(stderr.string).to match /ERROR param-error-message/
      expect(stderr.string).to match /FATAL param-fatal-message/
    end
  end

  context do

    before do
      allow(JavaBuildpack::Util::ConfigurationUtils).to receive(:load).with('logging', false).and_return({})
      described_class.reset
      described_class.setup app_dir
    end

    it 'should log all levels above INFO to console when no configuration has been set' do
      trigger

      expect(stderr.string).not_to match /DEBUG block-debug-message/
      expect(stderr.string).to match /INFO  block-info-message/
      expect(stderr.string).to match /WARN  block-warn-message/
      expect(stderr.string).to match /ERROR block-error-message/
      expect(stderr.string).to match /FATAL block-fatal-message/

      expect(stderr.string).not_to match /DEBUG param-debug-message/
      expect(stderr.string).to match /INFO  param-info-message/
      expect(stderr.string).to match /WARN  param-warn-message/
      expect(stderr.string).to match /ERROR param-error-message/
      expect(stderr.string).to match /FATAL param-fatal-message/
    end
  end

  context do

    before do
      described_class.reset
    end

    it 'should raise an error if get_logger called and not yet initialized' do
      expect { described_class.get_logger String }
      .to raise_error 'Attempted to get Logger for String before initialization'
    end

    it 'should raise an error if log_file called and not yet initialized' do
      expect { described_class.log_file }
      .to raise_error 'Attempted to get log file before initialization'
    end
  end

  def trigger
    logger.debug { 'block-debug-message' }
    logger.info { 'block-info-message' }
    logger.warn { 'block-warn-message' }
    logger.error { 'block-error-message' }
    logger.fatal { 'block-fatal-message' }

    logger.debug 'param-debug-message'
    logger.info 'param-info-message'
    logger.warn 'param-warn-message'
    logger.error 'param-error-message'
    logger.fatal 'param-fatal-message'
  end

end
