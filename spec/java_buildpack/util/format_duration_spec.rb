# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/util/format_duration'

describe 'duration' do # rubocop:disable RSpec/DescribeClass

  let(:millisecond) { 0.001 }
  let(:tenth) { 100 * millisecond }
  let(:second) { 10 * tenth }
  let(:minute) { 60 * second }
  let(:hour) { 60 * minute }

  it 'displays seconds' do
    expect_time_string '0.0s', millisecond
    expect_time_string '0.1s', tenth
    expect_time_string '1.0s', second
    expect_time_string '1.1s', second + tenth
    expect_time_string '1.1s', second + tenth + millisecond
  end

  it 'displays minutes' do
    expect_time_string '1m 0s', minute
    expect_time_string '1m 1s', minute + second
    expect_time_string '1m 1s', minute + second + tenth
    expect_time_string '1m 1s', minute + second + tenth + millisecond
  end

  it 'displays hours' do
    expect_time_string '1h 0m', hour
    expect_time_string '1h 1m', hour + minute
    expect_time_string '1h 1m', hour + minute + second
    expect_time_string '1h 1m', hour + minute + second + tenth
    expect_time_string '1h 1m', hour + minute + second + tenth + millisecond
  end

  def expect_time_string(expected, time)
    expect(time.duration).to eq(expected)
  end

end
