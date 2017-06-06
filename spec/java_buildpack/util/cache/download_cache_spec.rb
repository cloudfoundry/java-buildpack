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
require 'application_helper'
require 'internet_availability_helper'
require 'logging_helper'
require 'fileutils'
require 'java_buildpack/util/cache/download_cache'
require 'net/http'

describe JavaBuildpack::Util::Cache::DownloadCache do
  include_context 'application_helper'
  include_context 'internet_availability_helper'
  include_context 'logging_helper'

  let(:ca_certs_directory) { instance_double('Pathname', exist?: false, to_s: 'test-path') }

  let(:mutable_cache_root) { app_dir + 'mutable' }

  let(:immutable_cache_root) { app_dir + 'immutable' }

  let(:uri) { 'http://foo-uri/' }

  let(:uri_credentials) { 'http://test-username:test-password@foo-uri/' }

  let(:uri_secure) { 'https://foo-uri/' }

  let(:download_cache) { described_class.new(mutable_cache_root, immutable_cache_root) }

  before do
    described_class.const_set :CA_FILE, ca_certs_directory
  end

  it 'raises error if file cannot be found',
     :disable_internet do

    expect { download_cache.get uri }.to raise_error('Unable to find cached file for http://foo-uri/')
  end

  it 'returns file from immutable cache if internet is disabled',
     :disable_internet do

    touch immutable_cache_root, 'cached', 'foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
  end

  it 'returns file from mutable cache if internet is disabled',
     :disable_internet do

    touch mutable_cache_root, 'cached', 'foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
  end

  it 'downloads if cached file does not exist' do
    stub_request(:get, uri)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(Net::HTTP).to receive(:Proxy).and_call_original
    expect(Net::HTTP).not_to have_received(:Proxy).with('proxy', 9000, nil, nil)

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
    expect_complete_cache mutable_cache_root
  end

  it 'downloads with credentials if cached file does not exist' do
    stub_request(:get, uri)
      .with(headers: { 'Authorization' => 'Basic dGVzdC11c2VybmFtZTp0ZXN0LXBhc3N3b3Jk' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(Net::HTTP).to receive(:Proxy).and_call_original
    expect(Net::HTTP).not_to have_received(:Proxy).with('proxy', 9000, nil, nil)

    expect { |b| download_cache.get uri_credentials, &b }.to yield_file_with_content(/foo-cached/)
    expect_complete_cache mutable_cache_root
  end

  it 'follows redirects' do
    stub_request(:get, uri)
      .to_return(status: 301, headers: { Location: uri_secure })
    stub_request(:get, uri_secure)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
    expect_complete_cache mutable_cache_root
  end

  it 'retries failed downloads' do
    stub_request(:get, uri)
      .to_raise(SocketError)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
    expect_complete_cache mutable_cache_root
  end

  it 'returns cached data if unknown error occurs' do
    stub_request(:get, uri)
      .to_raise('DNS Error')

    touch immutable_cache_root, 'cached', 'foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
  end

  it 'returns cached data if retry limit is reached' do
    stub_request(:get, uri)
      .to_return(status: 500)

    touch immutable_cache_root, 'cached', 'foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
  end

  it 'does not overwrite existing information if 304 is received' do
    stub_request(:get, uri)
      .with(headers: { 'If-None-Match' => 'foo-etag', 'If-Modified-Since' => 'foo-last-modified' })
      .to_return(status: 304, body: '', headers: {})

    touch mutable_cache_root, 'cached', 'foo-cached'
    touch mutable_cache_root, 'etag', 'foo-etag'
    touch mutable_cache_root, 'last_modified', 'foo-last-modified'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
    expect_complete_cache mutable_cache_root
  end

  it 'overwrites existing information if 304 is not received' do
    stub_request(:get, uri)
      .with(headers: { 'If-None-Match' => 'old-foo-etag', 'If-Modified-Since' => 'old-foo-last-modified' })
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    touch mutable_cache_root, 'cached', 'old-foo-cached'
    touch mutable_cache_root, 'etag', 'old-foo-etag'
    touch mutable_cache_root, 'last_modified', 'old-foo-last-modified'

    expect { |b| download_cache.get uri, &b }.to yield_with_args(be_a(File), true)

    touch mutable_cache_root, 'cached', 'old-foo-cached'
    touch mutable_cache_root, 'etag', 'old-foo-etag'
    touch mutable_cache_root, 'last_modified', 'old-foo-last-modified'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)

    expect_complete_cache mutable_cache_root
  end

  it 'discards content with incorrect size' do
    stub_request(:get, uri)
      .to_return(status: 200, body: 'foo-cac', headers: { Etag:            'foo-etag',
                                                          'Last-Modified'  => 'foo-last-modified',
                                                          'Content-Length' => 10 })

    touch immutable_cache_root, 'cached', 'old-foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cached/)
  end

  it 'ignores incorrect size when encoded' do
    stub_request(:get, uri)
      .to_return(status: 200, body: 'foo-cac', headers: { Etag:              'foo-etag',
                                                          'Content-Encoding' => 'gzip',
                                                          'Last-Modified'    => 'foo-last-modified',
                                                          'Content-Length'   => 10 })

    touch immutable_cache_root, 'cached', 'old-foo-cached'

    expect { |b| download_cache.get uri, &b }.to yield_file_with_content(/foo-cac/)
  end

  context do

    let(:environment) { { 'http_proxy' => 'http://proxy:9000', 'HTTP_PROXY' => nil } }

    it 'uses http_proxy if specified' do
      stub_request(:get, uri)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      allow(Net::HTTP).to receive(:Proxy).with('proxy', 9000, nil, nil).and_call_original

      download_cache.get(uri) {}
    end

  end

  context do

    let(:environment) { { 'HTTP_PROXY' => 'http://proxy:9000', 'http_proxy' => nil } }

    it 'uses HTTP_PROXY if specified' do
      stub_request(:get, uri)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      allow(Net::HTTP).to receive(:Proxy).with('proxy', 9000, nil, nil).and_call_original

      download_cache.get(uri) {}
    end

  end

  context do

    let(:environment) { { 'https_proxy' => 'http://proxy:9000', 'HTTPS_PROXY' => nil } }

    it 'uses https_proxy if specified and URL is secure' do
      stub_request(:get, uri_secure)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      allow(Net::HTTP).to receive(:Proxy).with('proxy', 9000, nil, nil).and_call_original

      download_cache.get(uri_secure) {}
    end

  end

  context do

    let(:environment) { { 'HTTPS_PROXY' => 'http://proxy:9000', 'https_proxy' => nil } }

    it 'uses HTTPS_PROXY if specified and URL is secure' do
      stub_request(:get, uri_secure)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      allow(Net::HTTP).to receive(:Proxy).with('proxy', 9000, nil, nil).and_call_original

      download_cache.get(uri_secure) {}
    end

  end

  context do
    let(:environment) { { 'NO_PROXY' => '127.0.0.1,localhost,foo-uri,.foo-uri', 'HTTPS_PROXY' => 'http://proxy:9000' } }

    it 'does not use proxy if host in NO_PROXY' do
      stub_request(:get, uri_secure)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      expect(Net::HTTP).not_to have_received(:Proxy).with('proxy', 9000, nil, nil)

      download_cache.get(uri_secure) {}
    end

  end

  context do
    let(:environment) { { 'no_proxy' => '127.0.0.1,localhost,foo-uri,.foo-uri', 'https_proxy' => 'http://proxy:9000' } }

    it 'does not use proxy if host in no_proxy' do
      stub_request(:get, uri_secure)
        .to_return(status: 200, body: 'foo-cached', headers: { Etag:           'foo-etag',
                                                               'Last-Modified' => 'foo-last-modified' })

      allow(Net::HTTP).to receive(:Proxy).and_call_original
      expect(Net::HTTP).not_to have_received(:Proxy).with('proxy', 9000, nil, nil)

      download_cache.get(uri_secure) {}
    end

  end

  it 'does not use ca_file if the URL is not secure and directory does not exist' do
    stub_request(:get, uri)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(Net::HTTP).to receive(:Proxy).and_call_original
    allow(Net::HTTP).to receive(:start).with('foo-uri', 80, {}).and_call_original

    download_cache.get(uri) {}
  end

  it 'does not use ca_file if the URL is not secure and directory does exist' do
    stub_request(:get, uri)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(ca_certs_directory).to receive(:exist?).and_return(true)
    allow(Net::HTTP).to receive(:Proxy).and_call_original
    allow(Net::HTTP).to receive(:start).with('foo-uri', 80, {}).and_call_original

    download_cache.get(uri) {}
  end

  it 'does not use ca_file if the URL is secure and directory does not exist' do
    stub_request(:get, uri_secure)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(Net::HTTP).to receive(:Proxy).and_call_original
    allow(Net::HTTP).to receive(:start).with('foo-uri', 443, use_ssl: true).and_call_original

    download_cache.get(uri_secure) {}
  end

  it 'uses ca_file if the URL is secure and directory does exist' do
    stub_request(:get, uri_secure)
      .to_return(status: 200, body: 'foo-cached', headers: { Etag: 'foo-etag', 'Last-Modified' => 'foo-last-modified' })

    allow(ca_certs_directory).to receive(:exist?).and_return(true)
    allow(Net::HTTP).to receive(:Proxy).and_call_original
    allow(Net::HTTP).to receive(:start).with('foo-uri', 443, use_ssl: true, ca_file: 'test-path').and_call_original

    download_cache.get(uri_secure) {}
  end

  it 'deletes the cached file if it exists' do
    expect_file_deleted 'cached'
  end

  it 'deletes the etag file if it exists' do
    expect_file_deleted 'etag'
  end

  it 'deletes the last_modified file if it exists' do
    expect_file_deleted 'last_modified'
  end

  def cache_file(root, extension)
    root + "http%3A%2F%2Ffoo-uri%2F.#{extension}"
  end

  def expect_complete_cache(root)
    expect_file_content root, 'cached', 'foo-cached'
    expect_file_content root, 'etag', 'foo-etag'
    expect_file_content root, 'last_modified', 'foo-last-modified'
  end

  def expect_file_content(root, extension, content = '')
    file = cache_file root, extension
    expect(file).to exist
    expect(file.read).to eq(content)
  end

  def expect_file_deleted(extension)
    file = touch mutable_cache_root, extension
    expect(file).to exist

    download_cache.evict('http://foo-uri/')

    expect(file).not_to exist
  end

  def touch(root, extension, content = '')
    file = cache_file root, extension
    FileUtils.mkdir_p file.dirname
    file.open('w') { |f| f.write content }

    file
  end

end
