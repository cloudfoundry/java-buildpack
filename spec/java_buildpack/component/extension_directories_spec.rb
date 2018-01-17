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
require 'droplet_helper'
require 'java_buildpack/component/extension_directories'

describe JavaBuildpack::Component::ExtensionDirectories do
  include_context 'with droplet help'

  context do

    before do
      extension_directories.clear
    end

    it 'contains an added path' do
      extension_directories << droplet.sandbox

      expect(extension_directories).to include(droplet.sandbox)
    end

    it 'renders as path' do
      extension_directories << droplet.sandbox + 'extension-directories-1'
      extension_directories << droplet.sandbox + 'extension-directories-2'

      expect(extension_directories.as_paths).to eq('$PWD/.java-buildpack/extension_directories/' \
                                                   'extension-directories-1:$PWD/.java-buildpack/' \
                                                   'extension_directories/extension-directories-2')
    end
  end

  it 'renders empty string if path is empty' do
    extension_directories.clear
    expect(extension_directories.as_paths).not_to be
  end

end
