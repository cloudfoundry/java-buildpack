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

require 'java_buildpack/component'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Component

    # An abstraction around the additional libraries provided to a droplet by components.
    #
    # A new instance of this type should be created once for the application.
    class AdditionalLibraries < Array
      include JavaBuildpack::Util

      # Creates an instance of the +JAVA_OPTS+ abstraction.
      #
      # @param [Pathname] droplet_root the root directory of the droplet
      def initialize(droplet_root)
        @paths        = []
        @droplet_root = droplet_root
      end

      # Returns the contents of the collection as a classpath formatted as +-cp <value1>:<value2>+
      #
      # @return [String] the contents of the collection as a classpath
      def as_classpath
        qualified_paths = sort.map { |path| qualify_path path }

        "-cp #{qualified_paths.join ':'}" unless empty?
      end

      # Symlink the contents of the collection to a destination directory.
      #
      # @param [Pathname] destination the destination to link to
      # @return [Void]
      def link_to(destination)
        FileUtils.mkdir_p destination
        each { |path| (destination + path.basename).make_symlink(path.relative_path_from(destination)) }
      end

    end

  end
end
