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
require 'java_buildpack/util/application_cache'
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack::Util

  describe ApplicationCache do

    before do
      @previous_value = ARGV[1]
      ARGV[1] = nil
      $stdout = StringIO.new
    end

    after do
      ARGV[1] = @previous_value
    end

    TEST_URI = 'http://foo-uri/'
    TEST_VERSION = TokenizedVersion.new('1.0.0')

    it 'should raise an error if ARGV[1] is not defined' do
      -> { ApplicationCache.download('foo', TEST_VERSION, TEST_URI) }.should raise_error(/Application cache directory is undefined/)
    end

    it 'should download using HTTP into ARGV[1]' do
      Dir.mktmpdir do |root|
        ARGV[1] = root
        stub_request(:get, TEST_URI).to_return(
            status: 200,
            body: 'foo-cached',
            headers: {
                Etag: 'foo-etag',
                'Last-Modified' => 'foo-last-modified'
            }
        )
        ApplicationCache.download('foo', TEST_VERSION, TEST_URI) do |file|
          expect(file.path).to match(/http:%2F%2Ffoo-uri%2F\.cached$/)
        end
        expect(Dir[File.join(root, '*.cached')].size).to eq(1)
      end
    end

    it 'should not be possible to new up an instance' do
      -> { ApplicationCache.new }.should raise_error(/private method `new' called/)
    end

  end

end
