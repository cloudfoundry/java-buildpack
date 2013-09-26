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
require 'java_buildpack/util/global_cache'

module JavaBuildpack::Util

  describe GlobalCache do

    before do
      @previous_value = ENV.delete 'BUILDPACK_CACHE'

      stub_request(:get, 'http://foo-uri/')
      .with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '', headers: {})

      DownloadCache.class_variable_set :@@internet_checked, false
    end

    after do
      ENV['BUILDPACK_CACHE'] = @previous_value
      DownloadCache.class_variable_set :@@internet_checked, false
    end

    it 'should raise an error if BUILDPACK_CACHE is not defined' do
      -> { GlobalCache.new }.should raise_error
    end

    it 'should use BUILDPACK_CACHE directory' do
      stub_request(:get, 'http://foo-uri/').to_return(
          status: 200,
          body: 'foo-cached',
          headers: {
              Etag: 'foo-etag',
              'Last-Modified' => 'foo-last-modified'
          }
      )

      Dir.mktmpdir do |root|
        ENV['BUILDPACK_CACHE'] = root

        GlobalCache.new.get('http://foo-uri/') { }

        expect(Dir[File.join(root, '*.cached')].size).to eq(1)
      end
    end

  end

end
