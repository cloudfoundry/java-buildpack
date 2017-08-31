# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'component_helper'
require 'java_buildpack/container/dist_zip_like'

describe JavaBuildpack::Container::DistZipLike do
  include_context 'component_helper'

  it 'raises error if id method is unimplemented' do
    expect { component.send(:id) }.to raise_error "Method 'id' must be defined"
  end

  it 'raises error if supports? method is unimplemented' do
    expect { component.send(:supports?) }.to raise_error "Method 'supports?' must be defined"
  end

  it 'extends the CLASSPATH',
     app_fixture: 'container_dist_zip' do

    component.compile

    expect((app_dir + 'bin/application').read)
      .to match 'CLASSPATH=\$APP_HOME/.additional_libs/test-jar-1.jar:\$APP_HOME/.additional_libs/test-jar-2.jar:'
  end

  it 'extends the app_classpath',
     app_fixture: 'container_dist_zip_app_classpath' do

    component.compile

    expect((app_dir + 'application-root/bin/application').read)
      .to match 'declare -r app_classpath="\$app_home/../../.additional_libs/test-jar-1.jar:' \
      '\$app_home/../../.additional_libs/test-jar-2.jar:'
  end

  it 'returns command',
     app_fixture: 'container_dist_zip' do

    expect(component.release).to eq("test-var-2 test-var-1 JAVA_OPTS=$JAVA_OPTS #{java_home.as_env_var} exec " \
                                    '$PWD/bin/application')
  end

end
