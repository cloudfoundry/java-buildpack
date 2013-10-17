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

require 'java_buildpack/util'

module JavaBuildpack::Util

  # Common utilities for manipulating libraries (i.e. JARs)
  class LibraryUtils

    # Returns an +Array+ containing the paths of the JARs located in the given directory.
    #
    # @param [String] lib_directory the directory containing zero or more JARs
    # @return [Array<String>] the paths of the JARs located in the given directory
    def self.lib_jars(lib_directory)
      libs = []

      if lib_directory
        libs = Pathname.new(lib_directory).children
        .select { |file| file.extname == '.jar' }
        .sort
      end

      libs
    end
  end

end
