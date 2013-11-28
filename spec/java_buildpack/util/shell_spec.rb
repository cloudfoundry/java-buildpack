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
require 'console_helper'
require 'java_buildpack/util/shell'

describe JavaBuildpack::Util::Shell do
  include JavaBuildpack::Util::Shell
  include_context 'console_helper'

  it 'should return if command returns a zero exit code' do
    shell 'true'
  end

  it 'should raise an error if command returns a non-zero exit code' do
    expect { shell 'false' }.to raise_error
  end

end
