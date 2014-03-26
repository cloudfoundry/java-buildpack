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

require 'offline'

module Offline

  class TarFileTask < Rake::TaskLib
    include Offline

    attr_reader :targets

    def initialize(dependency_cache_task, stage_files_task)
      @targets = create_task([dependency_cache_task.targets, stage_files_task.targets].flatten, target)
    end

    private

    def target
      "#{BUILD_DIR}/java-buildpack-offline.tar.gz"
    end

    def create_task(dependencies, target)
      parent = File.dirname target

      directory parent
      file target => [dependencies, parent].flatten do |t|
        rake_output_message "Creating #{t.name}"
        `tar czf #{t.name} -C #{STAGING_DIR} .`
      end

      target
    end

  end

end
