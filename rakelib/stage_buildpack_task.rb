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

  class StageBuildpackTask < Rake::TaskLib
    include Offline

    attr_reader :targets

    def initialize(source_files)
      @targets = source_files.map { |source| create_task(source, target(source)) }
    end

    def target(source)
      "#{STAGING_DIR}/#{source}"
    end

    private

    def create_task(source, target)
      file(target => [source]) do |t|
        rm_f t.name, verbose: verbose?
        mkdir_p File.dirname(t.name), verbose: verbose?
        cp t.source, t.name, verbose: verbose?
      end

      target
    end

  end

end
