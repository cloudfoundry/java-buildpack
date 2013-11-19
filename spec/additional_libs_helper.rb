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
require 'application_helper'

shared_context 'additional_libs_helper' do
  include_context 'application_helper'

  let(:additional_libs_dir) { app_dir + '.lib' }

  before do
    FileUtils.mkdir_p additional_libs_dir
    FileUtils.cp_r 'spec/fixtures/additional_libs/.', additional_libs_dir
  end

end
