# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

require 'java_buildpack/component'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Component

    # An abstraction around the extension directories provided to a droplet by components.
    #
    # A new instance of this type should be created once for the application.
    class ExtensionDirectories < Array
      include JavaBuildpack::Util

      # Creates an instance of the +JAVA_OPTS+ abstraction.
      #
      # @param [Pathname] droplet_root the root directory of the droplet
      def initialize(droplet_root)
        @droplet_root = droplet_root
      end

      # Returns the contents of the collection as a colon-delimited paths formatted as +<value1>:<value2>+
      #
      # @return [String] the contents of the collection as a colon-delimited collection of paths
      def as_paths
        qualified_paths = sort.map { |path| qualify_path path }
        qualified_paths.join ':' unless empty?
      end

    end

  end
end
