# Cloud Foundry Buildpack Utilities
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
require 'tmpdir'

describe JavaBuildpack::ApplicationCache do

  before do
    @previous_value = ARGV[1]
    ARGV[1] = nil
  end

  after do
    ARGV[1] = @previous_value
  end

  it 'should raise an error if ARGV[1] is not defined' do
    lambda { JavaBuildpack::ApplicationCache.new }.should raise_error
  end

  it 'should use ARGV[1] directory' do
    stub_request(:get, 'http://foo-uri/').to_return(
        :status => 200,
        :body => 'foo-cached',
        :headers => {
            :Etag => 'foo-etag',
            'Last-Modified' => 'foo-last-modified'
        }
    )

    Dir.mktmpdir do |root|
      ARGV[1] = root

      JavaBuildpack::ApplicationCache.new().get('foo', 'http://foo-uri/') {}

      expect(File.exists?(File.join(root, 'foo.cached'))).to be_true
    end
  end

end
