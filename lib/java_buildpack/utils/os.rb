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

require 'rbconfig'

module JavaBuildpack

  # Utilities for finding out what OS the application is running on
  class OS
    @@host_os = RbConfig::CONFIG['host_os']

    # Match the current OS against a pattern
    #
    # @param [RegularExpression] pattern The pattern to match against
    # @return [Boolean] +true+ if the OS name matches the pattern, +false+ otherwise
    def self.is?(pattern)
      pattern === @@host_os
    end

    # Whether the current OS is Linux
    #
    # @return [Boolean] +true+ if the OS is Linux, +false+ otherwise
    def self.linux?
      is?(/linux|cygwin/)
    end

    # Whether the current OS is Mac
    #
    # @return [Boolean] +true+ if the OS is Mac, +false+ otherwise
    def self.mac?
      is?(/mac|darwin/)
    end

    # Whether the current OS is BSD
    #
    # @return [Boolean] +true+ if the OS is BSD, +false+ otherwise
    def self.bsd?
      is?(/bsd/)
    end

  end
end
