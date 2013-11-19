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
require 'buildpack_cache_helper'
require 'diagnostics_helper'
require 'java_buildpack/util/global_cache'

module JavaBuildpack::Util

  describe GlobalCache do
    include_context 'diagnostics_helper'

    before do
      stub_request(:get, 'http://foo-uri/').with(headers: { 'Accept' => '*/*', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '', headers: {})
    end

    it 'should raise an error if BUILDPACK_CACHE is not defined' do
      expect { GlobalCache.new }.to raise_error
    end

    context do
      include_context 'buildpack_cache_helper'

      it 'should use BUILDPACK_CACHE directory' do
        stub_request(:get, 'http://foo-uri/')
        .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

        GlobalCache.new.get('http://foo-uri/') {}

        expect(Dir[buildpack_cache_dir + '*.cached'].size).to eq(1)
      end
    end

  end

end
