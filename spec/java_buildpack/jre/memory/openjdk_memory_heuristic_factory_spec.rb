# Encoding: utf-8
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
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'
require 'java_buildpack/jre/memory/weight_balancing_memory_heuristic'
require 'java_buildpack/util/tokenized_version'
require 'rspec/expectations'

RSpec::Matchers.define :be_a_hash_like do |expected|
  match do |actual|
    expected['heap']['1m'] == actual['heap']['1m'] &&
        expected['metaspace']['2m'] == actual['metaspace']['2m'] &&
        expected['permgen']['3m'] == actual['permgen']['3m'] &&
        expected['stack']['4m'] == actual['stack']['4m']
  end
end

describe JavaBuildpack::Jre::OpenJDKMemoryHeuristicFactory do

  let(:heuristics) { { 'c' => 'd' } }

  let(:post_8) { JavaBuildpack::Util::TokenizedVersion.new('1.8.0') }

  let(:pre_8) { JavaBuildpack::Util::TokenizedVersion.new('1.7.0') }

  let(:sizes) { { 'a' => 'b' } }

  let(:expected_java_memory_options) do
    {
        'heap' => ->(v) { %W(-Xmx#{v} -Xms#{v}) },
        'metaspace' => ->(v) { %W(-XX:MaxMetaspaceSize=#{v} -XX:MetaspaceSize=#{v}) },
        'permgen' => ->(v) { %W(-XX:MaxPermSize=#{v} -XX:PermSize=#{v}) },
        'stack' => ->(v) { %W(-Xss#{v}) }
    }
  end

  it 'should pass the appropriate constructor parameters for versions prior to 1.8' do
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new)
                                                                 .with(sizes, heuristics, %w(heap stack native permgen),
                                                                       be_a_hash_like(expected_java_memory_options))

    described_class.create_memory_heuristic(sizes, heuristics, pre_8)
  end

  it 'should pass the appropriate constructor parameters for versions 1.8 and higher' do
    allow(JavaBuildpack::Jre::WeightBalancingMemoryHeuristic).to receive(:new)
                                                                 .with(sizes, heuristics, %w(heap stack native metaspace),
                                                                       be_a_hash_like(expected_java_memory_options))

    described_class.create_memory_heuristic(sizes, heuristics, post_8)
  end

end
