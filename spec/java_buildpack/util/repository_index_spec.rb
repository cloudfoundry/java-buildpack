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
require 'java_buildpack/util/repository_index'

module JavaBuildpack::Util

  describe RepositoryIndex do

    let(:application_cache) { double('ApplicationCache') }

    it 'should load index' do
      JavaBuildpack::Util::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('test-key', 'test-uri/index.yml')
        .and_yield(File.open('spec/fixtures/test-index.yml'))

      repository_index = RepositoryIndex.new('test-key', 'test-uri')

      expect(repository_index).to include('resolved-version' => 'resolved-uri')

    end

  end

end
