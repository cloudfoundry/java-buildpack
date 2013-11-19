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

shared_context 'memory_limit_helper' do

  previous_memory_limit = ENV['MEMORY_LIMIT']

  before do |example|
    memory_limit = example.metadata[:memory_limit]
    ENV['MEMORY_LIMIT'] = memory_limit if memory_limit
  end

  after do
    ENV['MEMORY_LIMIT'] = previous_memory_limit
  end

end
