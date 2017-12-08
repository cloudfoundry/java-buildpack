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
require 'application_helper'
require 'logging_helper'
require 'java_buildpack/component/additional_libraries'
require 'java_buildpack/component/droplet'
require 'java_buildpack/component/environment_variables'
require 'java_buildpack/component/extension_directories'
require 'java_buildpack/component/immutable_java_home'
require 'java_buildpack/component/java_opts'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/component/networking'
require 'java_buildpack/component/security_providers'
require 'java_buildpack/util/snake_case'
require 'java_buildpack/util/tokenized_version'
require 'pathname'

shared_context 'droplet_helper' do
  include_context 'application_helper'
  include_context 'logging_helper'

  let(:additional_libraries) { JavaBuildpack::Component::AdditionalLibraries.new app_dir }

  let(:additional_libs_directory) { droplet.root + '.additional_libs' }

  let(:component_id) { described_class.to_s.split('::').last.snake_case }

  let(:droplet) do
    JavaBuildpack::Component::Droplet.new(additional_libraries, component_id, environment_variables,
                                          extension_directories, java_home, java_opts, app_dir, networking,
                                          security_providers)
  end

  let(:extension_directories) { JavaBuildpack::Component::ExtensionDirectories.new app_dir }

  let(:sandbox) { droplet.sandbox }

  let(:java_home) do
    JavaBuildpack::Component::ImmutableJavaHome.new java_home_delegate, app_dir
  end

  let(:java_home_delegate) do
    delegate         = JavaBuildpack::Component::MutableJavaHome.new
    delegate.root    = app_dir + '.test-java-home'
    delegate.version = JavaBuildpack::Util::TokenizedVersion.new('1.7.0_55')

    delegate
  end

  let(:environment_variables) do
    java_opts = JavaBuildpack::Component::EnvironmentVariables.new app_dir
    java_opts.concat %w[test-var-2 test-var-1]
    java_opts
  end

  let(:java_opts) do
    java_opts = JavaBuildpack::Component::JavaOpts.new app_dir
    java_opts.concat %w[test-opt-2 test-opt-1]
    java_opts
  end

  let(:networking) { JavaBuildpack::Component::Networking.new }

  let(:security_providers) { JavaBuildpack::Component::SecurityProviders.new }

  before do
    FileUtils.cp_r 'spec/fixtures/additional_libs/.', additional_libs_directory
    additional_libs_directory.children.each { |child| additional_libraries << child }

    extension_directories << sandbox + 'test-extension-directory-1'
    extension_directories << sandbox + 'test-extension-directory-2'

    security_providers.concat %w[test-security-provider-1 test-security-provider-2]
  end

end
