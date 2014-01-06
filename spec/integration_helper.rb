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
require 'application_helper'
require 'console_helper'
require 'logging_helper'
require 'open3'

shared_context 'integration_helper' do
  include_context 'application_helper'
  include_context 'console_helper'
  include_context 'logging_helper'

  def run(command)
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      capture_output stdout, stderr
      yield wait_thr.value if block_given?
    end
  end

end
