# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

require 'java_buildpack/util'
require 'pathname'

module JavaBuildpack::Util

  # Utilities for dealing with .class files
  class ClassFileUtils

    private_class_method :new

    class << self

      # Returns all the .class files in the given directory
      #
      # @param [Application] application the application to search
      # @return [Array] a possibly empty list of files
      def class_files(application)
        (application.root + CLASS_FILE_PATTERN).glob.reject { |path| path.directory? }.sort
      end

      private

      CLASS_FILE_PATTERN = '**/*.class'.freeze

    end

  end

end
