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

require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

# RSpec Tasks
RSpec::Core::RakeTask.new
CLOBBER.include 'coverage'

# Rubocop Tasks
Rubocop::RakeTask.new

# Yard Tasks
YARD::Rake::YardocTask.new
CLEAN.include '.yardoc'
CLOBBER.include 'doc'

desc 'Check that all APIs have been documented'
task :check_api_doc do
  output = `yard stats --list-undoc`
  abort "\nFailed due to undocumented public API:\n\n#{output}" if output !~ /100.00% documented/
end

# Offline Package Tasks
STAGING = 'build/staging'.freeze

task :stage
CLEAN.include STAGING

FileList['bin/**/*', 'config/**/*', 'lib/**/*', 'resources/**/*'].each do |source|
  unless File.directory?(source)
    target = "#{STAGING}/#{source}"
    parent = File.dirname target

    directory parent
    file(target => [source, parent]) { |t| cp t.source, t.name }
    task stage: target
  end
end

# Default Task
task default: %w(rubocop check_api_doc spec)
