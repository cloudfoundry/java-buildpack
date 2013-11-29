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

require 'java_buildpack/application'

module JavaBuildpack::Application

  # An abstraction encapsulating the +JAVA_HOME+ of an application
  class JavaHome < String

    # Creates an instance of the +JAVA_HOME+ abstraction.
    #
    # @param [Pathname] root the root directory of the application
    def initialize(root)
      super('')
      @root = root
    end

    # Sets the path to +JAVA_HOME+
    #
    # @param [Pathname] path the path to +JAVA_HOME+
    def set(path)
      clear.concat "$PWD/#{path.relative_path_from(@root)}"
    end

    # Returns the contents as an environment variable formatted as +JAVA_HOME="<value>"+
    #
    # @return [String] the contents as an environment variable
    def as_env_var
      "JAVA_HOME=#{self}"
    end

  end

end
