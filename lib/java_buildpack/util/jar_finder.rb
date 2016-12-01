# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

require 'pathname'
require 'java_buildpack/util'

module JavaBuildpack
  module Util

    # A base class for utilities that need to find a JAR file
    class JarFinder

      # Creates a new instance
      #
      # @param [RegExp] pattern the pattern to use when filtering JAR files
      def initialize(pattern)
        @pattern = pattern
      end

      # Indicates whether an application has a JAR file
      #
      # @param [Application] application the application to search
      # @return [Boolean] +true+ if the application has a JAR file, +false+ otherwise
      def is?(application)
        jar application
      end

      # The version of the JAR file used by the application
      #
      # @param [Application] application the application to search
      # @return [String] the version of the JAR file used by the application
      def version(application)
        jar(application).to_s.match(@pattern)[1]
      end

      private

      def jar(application)
        (application.root + '**/lib/*.jar').glob.find { |jar| jar.to_s =~ @pattern }
      end

    end

  end
end
