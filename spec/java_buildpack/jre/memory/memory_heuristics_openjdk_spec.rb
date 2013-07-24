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
require 'java_buildpack/jre/memory/memory_heuristics_openjdk'

module JavaBuildpack::Jre

  describe MemoryHeuristicsOpenJDK do

    it 'should raise an error if an invalid size is specified' do
      expect { MemoryHeuristicsOpenJDK.new({ 'native' => 'test-value' }, { }) }.to raise_error("'native' is not a valid memory size")
    end

    it 'should raise an error if an invalid heuristic is specified' do
      expect { MemoryHeuristicsOpenJDK.new({}, { 'permgen' => 'test-value' }) }.to raise_error("'permgen' is not a valid memory heuristic")
    end

    it 'should map memory size to JAVA_OPTS' do
      with_memory_limit('1G') do
        output = MemoryHeuristicsOpenJDK.new(
          {},
          { 'heap' => 0.75, 'metaspace' => 0.1, 'stack' => 0.05, 'native' => 0.1 }
        ).resolve

        expect(output.length).to eq(3)
        expect(output).to include('-Xmx768M')
        expect(output).to include('-XX:MaxMetaspaceSize=104857K')
        expect(output).to include('-Xss1M')
      end
    end

    def with_memory_limit(memory_limit)
      previous_value, ENV['MEMORY_LIMIT'] = ENV['MEMORY_LIMIT'], memory_limit
      yield
    ensure
      ENV['MEMORY_LIMIT'] = previous_value
    end

  end

end
