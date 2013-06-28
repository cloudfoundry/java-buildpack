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

require 'java_buildpack/framework'
require 'shellwords'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for contributing custom Java options to an application
  # at runtime.
  class JavaOpts

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties provided by the user
    def initialize(context = {})
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
    end

    # Detects whether this application contributes Java options.
    #
    # @return [String] returns +java-opts+ if Java options have been set by the user
    def detect
      @configuration.has_key?(CONFIGURATION_PROPERTY) ? CONTAINER_NAME : nil
    end

    # Does nothing as no transformations are required when contributing Java options
    #
    # @return [void]
    def compile
    end

    # Adds the contents of +java.opts+ to the +context[:java_opts]+ for use when running the application
    #
    # @return [void]
    def release
      @configuration[CONFIGURATION_PROPERTY].shellsplit.map do |java_opt|
        @java_opts << java_opt.gsub(/([\s])/, '\\\\\1')
      end
    end

    private

    CONFIGURATION_PROPERTY = 'java_opts'.freeze

    CONTAINER_NAME = 'java-opts'.freeze

  end

end
