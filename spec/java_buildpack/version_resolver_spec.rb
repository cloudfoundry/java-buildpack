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

describe JavaBuildpack::VersionResolver do

  VERSIONS = [
    '1.6.0_26',
    '1.6.0_27',
    '1.6.1_14',
    '1.7.0_19',
    '1.7.0_21',
    '1.8.0_M-7',
    '1.8.0_05',
    '2.0.0'
  ]

  it 'resolves the latest version if no candidate is supplied' do
    expect(JavaBuildpack::VersionResolver.resolve(nil, VERSIONS)).to eq('2.0.0')
    expect(JavaBuildpack::VersionResolver.resolve('', VERSIONS)).to eq('2.0.0')
  end

  it 'resolves a wildcard major version' do
    expect(JavaBuildpack::VersionResolver.resolve('+', VERSIONS)).to eq('2.0.0')
  end

  it 'resolves a wildcard minor version' do
    expect(JavaBuildpack::VersionResolver.resolve('1.+', VERSIONS)).to eq('1.8.0_05')
  end

  it 'resolves a wildcard micro version' do
    expect(JavaBuildpack::VersionResolver.resolve('1.6.+', VERSIONS)).to eq('1.6.1_14')
  end

  it 'resolves a wildcard qualifier' do
    expect(JavaBuildpack::VersionResolver.resolve('1.6.0_+', VERSIONS)).to eq('1.6.0_27')
    expect(JavaBuildpack::VersionResolver.resolve('1.8.0_+', VERSIONS)).to eq('1.8.0_05')
  end

  it 'resolves a non-wildcard version' do
    expect(JavaBuildpack::VersionResolver.resolve('1.6.0_26', VERSIONS)).to eq('1.6.0_26')
    expect(JavaBuildpack::VersionResolver.resolve('2.0.0', VERSIONS)).to eq('2.0.0')
  end

  it 'resolves a non-digit qualifier' do
    expect(JavaBuildpack::VersionResolver.resolve('1.8.0_M-7', VERSIONS)).to eq('1.8.0_M-7')
  end

  it 'should order qualifiers correctly' do
    expect(JavaBuildpack::VersionResolver.resolve('1.7.0_+', ['1.7.0_28', '1.7.0_28a'])).to eq('1.7.0_28a')
  end

  it 'should raise an exception when the major version is not numeric' do
    expect { JavaBuildpack::VersionResolver.resolve('A', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when the minor version is not numeric' do
    expect { JavaBuildpack::VersionResolver.resolve('1.A', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1..0', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when the micro version is not numeric' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.A', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1.6..', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1.6_26', VERSIONS) }.to raise_error
  end

  it 'should raise an exception if no version can be resolved' do
    expect { JavaBuildpack::VersionResolver.resolve('2.1.0', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when major version is not legal' do
    expect { JavaBuildpack::VersionResolver.resolve('1+', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when minor version is not legal' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6+', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when micro version is not legal' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0+', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when qualifier version is not legal' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0_05+', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when the qualifier is not letter, number, or hyphen' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0_?', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0__5', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0_A.', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when a major version wildcard is folowed by anything' do
    expect { JavaBuildpack::VersionResolver.resolve('+.6.0_26', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when a minor version wildcard is folowed by anything' do
    expect { JavaBuildpack::VersionResolver.resolve('1.+.0_26', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when a micro version wildcard is folowed by anything' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.+_26', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when too many components are specified' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0.25', VERSIONS) }.to raise_error
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0.25_27', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when not enough components are specified' do
    expect { JavaBuildpack::VersionResolver.resolve('_25', VERSIONS) }.to raise_error
  end

  it 'should raise an exception when a wildcard is specified in the versions collection' do
    expect { JavaBuildpack::VersionResolver.resolve('1.6.0_25', ['+']) }.to raise_error
  end

end
