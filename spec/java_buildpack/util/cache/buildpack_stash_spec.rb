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
require 'logging_helper'
require 'java_buildpack/util/cache/buildpack_stash'

describe JavaBuildpack::Util::Cache::BuildpackStash do
  include_context 'logging_helper'

  let(:buildpack_stash) { described_class.new }

  let(:mutable_file_cache) { double('mutable file cache', persist_file: nil) }

  let(:trigger) { buildpack_stash.look_aside(mutable_file_cache, 'http://foo-uri/') }

  it 'should fail look_aside if the buildpack cache is not defined' do
    expect { trigger }.to raise_error /Buildpack cache not defined/
  end

  context do
    include_context 'buildpack_cache_helper'

    it 'should persist a stashed file' do
      touch java_buildpack_cache_dir, 'cached', 'foo-stashed'
      trigger
      stash_file = cache_file(java_buildpack_cache_dir, 'cached')
      expect(mutable_file_cache).to have_received(:persist_file).with(stash_file)
    end

    it 'should fail if the stash does not contain the relevant file' do
      expect { trigger }.to raise_error /Buildpack cache does not contain/
    end
  end

  def touch(root, extension, content = '')
    file = cache_file root, extension
    FileUtils.mkdir_p file.dirname
    file.open('w') { |f| f.write(content) }

    file
  end

  def cache_file(root, extension)
    root + "http:%2F%2Ffoo-uri%2F.#{extension}"
  end
end
