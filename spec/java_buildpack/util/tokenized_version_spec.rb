# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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
require 'java_buildpack/util/tokenized_version'

describe JavaBuildpack::Util::TokenizedVersion do

  it 'defaults to a wildcard if no version is supplied' do
    expect(described_class.new(nil)).to eq(described_class.new('+'))
  end

  it 'orders major versions' do
    expect(described_class.new('3.0.0')).to be > described_class.new('2.0.0')
    expect(described_class.new('10.0.0')).to be > described_class.new('2.0.0')
  end

  it 'orders minor versions' do
    expect(described_class.new('0.3.0')).to be > described_class.new('0.2.0')
    expect(described_class.new('0.10.0')).to be > described_class.new('0.2.0')
  end

  it 'orders micro versions' do
    expect(described_class.new('0.0.3')).to be > described_class.new('0.0.2')
    expect(described_class.new('0.0.10')).to be > described_class.new('0.0.2')
  end

  it 'orders qualifiers' do
    expect(described_class.new('1.7.0_28a')).to be > described_class.new('1.7.0_28')
  end

  it 'accepts a qualifier with embedded periods and hyphens' do
    described_class.new('0.5.0_BUILD-20120731.141622-16')
  end

  it 'raises an exception when the major version is not numeric' do
    expect { described_class.new('A') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when the minor version is not numeric' do
    expect { described_class.new('1.A') }.to raise_error(/Invalid/)
    expect { described_class.new('1..0') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when the micro version is not numeric' do
    expect { described_class.new('1.6.A') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6..') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6._0') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6_26') }.to raise_error(/Invalid/)
  end

  it 'accepts wildcards when legal' do
    described_class.new('+')
    described_class.new('1.+')
    described_class.new('1.1.+')
    described_class.new('1.1.1_+')
    described_class.new('1.1.1_1+')
  end

  it 'raises an exception when micro version is missing' do
    expect { described_class.new('1.6') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when major version is not legal' do
    expect { described_class.new('1+') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when minor version is not legal' do
    expect { described_class.new('1.6+') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when micro version is not legal' do
    expect { described_class.new('1.6.0+') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when the qualifier is not letter, number, or hyphen' do
    expect { described_class.new('1.6.0_?') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6.0__5') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6.0_A.') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when a major version wildcard is followed by anything' do
    expect { described_class.new('+.6.0_26') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when a minor version wildcard is followed by anything' do
    expect { described_class.new('1.+.0_26') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when a micro version wildcard is followed by anything' do
    expect { described_class.new('1.6.+_26') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when too many components are specified' do
    expect { described_class.new('1.6.0.25') }.to raise_error(/Invalid/)
    expect { described_class.new('1.6.0.25_27') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when not enough components are specified' do
    expect { described_class.new('_25') }.to raise_error(/Invalid/)
  end

  it 'raises an exception when a wildcard is specified but should not be' do
    expect { described_class.new('+', false) }.to raise_error(/Invalid/)
    expect { described_class.new('1.+', false) }.to raise_error(/Invalid/)
    expect { described_class.new('1.1.+', false) }.to raise_error(/Invalid/)
    expect { described_class.new('1.1.1_+', false) }.to raise_error(/Invalid/)
    expect { described_class.new('1.1.1_1+', false) }.to raise_error(/Invalid/)
  end

  it 'raises an exception when a version ends with a component separator' do
    expect { described_class.new('1.') }.to raise_error(/Invalid/)
    expect { described_class.new('1.7.') }.to raise_error(/Invalid/)
    expect { described_class.new('1.7.0_') }.to raise_error(/Invalid/)
  end

  it 'accepts a version has a number of components acceptable to check_size' do
    described_class.new('1.2.3_4').check_size(4)
  end

  it 'raises an exception when a version has too many components for check_size' do
    expect { described_class.new('1.2.3_4').check_size(3) }.to raise_error(/too many version components/)
  end

end
