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

require 'rake/tasklib'
require 'rakelib/package'
require 'yaml'

module Package

  class StageBuildpackTask < Rake::TaskLib
    include Package

    def initialize(source_files)
      source_files.map { |source| multitask PACKAGE_NAME => [copy_task(source, target(source))] }
      multitask PACKAGE_NAME => [version_task]
      disable_remote_downloads_task if BUILDPACK_VERSION.offline
    end

    private

    def copy_task(source, target)
      parent = File.dirname target

      directory parent
      file(target => [source, parent]) do |t|
        cp t.source, t.name

        if t.source.include? 'bin'
          chmod 0o755, t.name
        else
          chmod 0o644, t.name
        end
      end

      target
    end

    def disable_remote_downloads_task
      file "#{STAGING_DIR}/config/cache.yml" do |t|
        content = File.open(t.source, 'r') { |f| f.read.gsub(/enabled/, 'disabled') }
        File.open(t.name, 'w') { |f| File.write(f, content) }
      end
    end

    def target(source)
      "#{STAGING_DIR}/#{source}"
    end

    def version_task
      target = target('config/version.yml')
      parent = File.dirname target

      directory parent
      file target => [parent] do |t|
        File.open(t.name, 'w') do |f|
          File.write(f, BUILDPACK_VERSION.to_hash.to_yaml)
        end
      end

      target
    end

  end

end
