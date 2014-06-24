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

require 'rspec/expectations'
require 'rspec/matchers/built_in/yield'

RSpec::Matchers.define :yield_file_with_content do |expected|
  match do |block|
    probe = RSpec::Matchers::BuiltIn::YieldProbe.probe(block)
    probe.yielded_once?(:yield_with_args) && content(probe.single_yield_args.first) =~ expected
  end

  supports_block_expectations

  def content(file)
    File.read(file)
  end
end
