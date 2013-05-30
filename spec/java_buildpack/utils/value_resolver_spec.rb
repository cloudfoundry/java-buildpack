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

describe JavaBuildpack::ValueResolver do

  ENV_VAR_NAME = 'ENV_VAR'

  ENV_VAR_VALUE = 'env-var-value'

  SYS_PROP_NAME = 'system.property'

  SYS_PROP_VALUE = 'system-property-value'

  it 'should fail when no directory is specified on the constructor' do
    expect { JavaBuildpack::ValueResolver.new(nil) }.to raise_error
    expect { JavaBuildpack::ValueResolver.new('') }.to raise_error
  end

  it 'should fail when multiple system.properties files are found' do
    expect { JavaBuildpack::ValueResolver.new('spec/fixtures/multiple_system_properties') }.to raise_error
  end

  it 'should return the value of a specified environment variable' do
    old_property = ENV[ENV_VAR_NAME]
    ENV[ENV_VAR_NAME] = ENV_VAR_VALUE

    begin
      value_resolver = JavaBuildpack::ValueResolver.new('spec/fixtures/no_system_properties')
      value = value_resolver.resolve(ENV_VAR_NAME, SYS_PROP_NAME)

      expect(value).to eq(ENV_VAR_VALUE)
    ensure
      ENV[ENV_VAR_NAME] = old_property
    end
  end

  it 'should return the value of a specified property from system.properties' do
    value_resolver = JavaBuildpack::ValueResolver.new('spec/fixtures/single_system_properties')
    value = value_resolver.resolve(ENV_VAR_NAME, SYS_PROP_NAME)

    expect(value).to eq(SYS_PROP_VALUE)
  end

  it 'should return nil when neither the specified environment variable is set nor the property is specified in system.properties' do
    value_resolver = JavaBuildpack::ValueResolver.new('spec/fixtures/no_system_properties')
    value = value_resolver.resolve(ENV_VAR_NAME, SYS_PROP_NAME)

    expect(value).to be_nil
  end

  it 'should return the value of a specified environment variable when the property is also specified in system.properties' do
    old_property = ENV[ENV_VAR_NAME]
    ENV[ENV_VAR_NAME] = ENV_VAR_VALUE

    begin
      value_resolver = JavaBuildpack::ValueResolver.new('spec/fixtures/single_system_properties')
      value = value_resolver.resolve(ENV_VAR_NAME, SYS_PROP_NAME)

      expect(value).to eq(ENV_VAR_VALUE)
    ensure
      ENV[ENV_VAR_NAME] = old_property
    end
  end
end
