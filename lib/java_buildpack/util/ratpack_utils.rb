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

require 'pathname'
require 'java_buildpack/util'

module JavaBuildpack
  module Util

    # Utilities for dealing with Ratpack applications
    class RatpackUtils

      private_class_method :new

      class << self

        # Indicates whether a application is a Ratpack application
        #
        # @param [Application] application the application to search
        # @return [Boolean] +true+ if the application is a Ratpack application, +false+ otherwise
        def is?(application)
          (application.root + RATPACK_FILE_PATTERN).glob.any?
        end

        RATPACK_FILE_PATTERN = '**/app/{R,r}atpack.groovy'.freeze

        private_constant :RATPACK_FILE_PATTERN

      end

    end

  end
end
