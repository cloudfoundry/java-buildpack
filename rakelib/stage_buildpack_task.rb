# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2014 the original author or authors.
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

module Package

  class StageBuildpackTask < Rake::TaskLib
    include Package

    def initialize(source_files)
      source_files.map { |source| create_task(source, target(source)) }

      if OFFLINE
        file "#{STAGING_DIR}/config/cache.yml" do |t|
          content = File.open(t.source, 'r') { |f| f.read.gsub(/enabled/, 'disabled') }
          File.open(t.name, 'w') { |f| f.write content }
        end
      end
    end

    def target(source)
      "#{STAGING_DIR}/#{source}"
    end

    private

    def create_task(source, target)
      parent = File.dirname target

      directory parent
      file(target => [source, parent]) do |t|
        cp t.source, t.name
      end

      task PACKAGE_NAME => [target]
    end

  end

end
