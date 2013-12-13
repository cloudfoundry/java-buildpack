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

require 'java_buildpack/component'
require 'java_buildpack/component/qualify_path'
require 'java_buildpack/component/immutable_java_home'

module JavaBuildpack::Component

  # An abstraction around the +JAVA_HOME+ path used by the droplet.  This implementation is immutable and should be
  # passed to any component that is not a jre.
  #
  # A new instance of this type should be created once for the application.
  class MutableJavaHome < ImmutableJavaHome
    include JavaBuildpack::Component

    # @!attribute [r] root
    #   @return [String] the root of the droplet's +JAVA_HOME+
    attr_reader :root

    # Creates a new instance of the java home abstraction
    #
    # @param [Pathname] droplet_root the root directory of the droplet
    def initialize(droplet_root)
      @droplet_root = droplet_root
    end

    # Sets the root of the droplet's +JAVA_HOME+
    #
    # @param [Pathname] value the root of the droplet's +JAVA_HOME+
    def root=(value)
      @root = qualify_path value
    end

  end

end
