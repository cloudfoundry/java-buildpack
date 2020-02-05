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
require 'rake/tasklib'
require 'rakelib/package'
require 'zip'

module Package

  class PackageTask < Rake::TaskLib
    include Package

    def initialize
      directory BUILD_DIR
      directory STAGING_DIR

      CLEAN.include BUILD_DIR, STAGING_DIR

      desc 'Create packaged buildpack'
      task package: [PACKAGE_NAME]

      multitask PACKAGE_NAME => [BUILD_DIR, STAGING_DIR] do |t|
        rake_output_message "Creating #{t.name}"

        Zip::File.open(t.name, Zip::File::CREATE) do |zipfile|
          Dir[File.join(STAGING_DIR, '**', '**')].each do |file|
            zipfile.add(file.sub("#{STAGING_DIR}/", ''), file)
          end
        end
      end
    end

  end

end
