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
require 'yaml'

describe JavaBuildpack::Release do

  it 'should return the execution command payload' do
    jre_selector = double('JreSelector', :vendor => 'test-vendor', :version => 'test-version', :uri => 'test-uri', :stack_size => nil, :heap_size_maximum => nil)
    JavaBuildpack::JreProperties.stub(:new).with('spec/fixtures/no_system_properties').and_return(jre_selector)

    payload = JavaBuildpack::Release.new('spec/fixtures/no_system_properties').run
    expect(payload).to eq({
                              'addons' => [],
                              'config_vars' => {},
                              'default_process_types' => {
                                  'web' => '.java/bin/java -cp . com.gopivotal.SimpleJava'
                              }
                          }.to_yaml)
  end

  it 'should include specified options' do
    jre_selector = double('JreSelector', :vendor => 'test-vendor', :version => 'test-version', :uri => 'test-uri', :stack_size => '128k', :heap_size_maximum => '64m')
    JavaBuildpack::JreProperties.stub(:new).with('spec/fixtures/java_options').and_return(jre_selector)

    payload = JavaBuildpack::Release.new('spec/fixtures/java_options').run
    expect(payload).to eq({
                              'addons' => [],
                              'config_vars' => {},
                              'default_process_types' => {
                                  'web' => '.java/bin/java -cp . com.gopivotal.SimpleJava -Xss128k -Xmx=64m'
                              }
                          }.to_yaml)
  end

end
