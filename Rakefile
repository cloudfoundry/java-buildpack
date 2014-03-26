# Encoding: utf-8
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

$LOAD_PATH.unshift File.expand_path('../rakelib', __FILE__)

require 'rake/clean'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new
CLOBBER << 'coverage'

require 'rubocop/rake_task'
Rubocop::RakeTask.new

require 'yard'
YARD::Rake::YardocTask.new
CLEAN << '.yardoc'
CLOBBER << 'doc'

desc 'Check that all APIs have been documented'
task :check_api_doc do
  output = `yard stats --list-undoc`
  abort "\nFailed due to undocumented public API:\n\n#{output}" if output !~ /100.00% documented/
end

require 'pathname'
require_relative 'rakelib/dependency_cache_task'
require_relative 'rakelib/offline'
require_relative 'rakelib/stage_buildpack_task'
require_relative 'rakelib/tar_file_task'

CLOBBER << Offline::BUILD_DIR
CLEAN << Offline::STAGING_DIR

dependency_cache_task = Offline::DependencyCacheTask.new
stage_files_task      = Offline::StageBuildpackTask.new(Dir['bin/**/*', 'config/**/*', 'lib/**/*', 'resources/**/*']
                                                        .reject { |f| File.directory? f })
tar_file_task         = Offline::TarFileTask.new(dependency_cache_task, stage_files_task)

file "#{Offline::STAGING_DIR}/config/cache.yml" do |t|
  content = Pathname.new(t.source).read.gsub(/enabled/, 'disabled')
  Pathname.new(t.name).open('w') { |file| file.write content }
end

desc 'Create a buildpack for use offline'
task offline: [tar_file_task.targets]

task default: %w(rubocop check_api_doc spec)
