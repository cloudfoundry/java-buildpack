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

require 'rake/clean'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new
CLEAN.include 'coverage'

require 'rubocop/rake_task'
RuboCop::RakeTask.new { |t| t.requires << 'rubocop-rspec' }

require 'yard'
YARD::Rake::YardocTask.new
CLEAN.include '.yardoc', 'doc'

desc 'Check that all APIs have been documented'
task :check_api_doc do
  output = `yard stats --list-undoc`
  abort "\nFailed due to undocumented public API:\n\n#{output}" if output !~ /100.00% documented/
end

$LOAD_PATH.unshift File.expand_path(__dir__)
require 'rakelib/dependency_cache_task'
require 'rakelib/stage_buildpack_task'
require 'rakelib/package_task'
require 'rakelib/versions_task'
Package::DependencyCacheTask.new
Package::StageBuildpackTask.new(Dir['bin/**/*', 'config/**/*', 'lib/**/*', 'resources/**/*', 'LICENSE', 'NOTICE']
                                  .reject { |f| File.directory? f })
Package::PackageTask.new
Package::VersionsTask.new

task default: %w[rubocop check_api_doc spec]
