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
require 'java_buildpack/util/qualify_path'

module JavaBuildpack::Component

  # An abstraction encapsulating the +JAVA_OPTS+ of an application.
  #
  # A new instance of this type should be created once for the application.
  class JavaOpts < Array
    include JavaBuildpack::Util

    # Creates an instance of the +JAVA_OPTS+ abstraction.
    #
    # @param [Pathname] droplet_root the root directory of the droplet
    def initialize(droplet_root)
      @droplet_root = droplet_root
    end

    # Adds a +javaagent+ entry to the +JAVA_OPTS+.  Prepends +$PWD+ to the path (relative to the droplet root) to
    # ensure that the path is always accurate.
    #
    # @param [Pathname] path the path to the +javaagent+ JAR
    # @return [JavaOpts]     +self+ for chaining
    def add_javaagent(path)
      self << "-javaagent:#{qualify_path path}"
      self
    end

    # Adds a system property to the +JAVA_OPTS+.  Ensures that the key is prepended with +-D+.  If the value is a
    # +Pathname+, then prepends +$PWD+ to the path (relative to the droplet root) to ensure that the path is always
    # accurate.  Otherwise, uses the value as-is.
    #
    # @param [String] key             the key of the system property
    # @param [Pathname, String] value the value of the system property
    # @return [JavaOpts]              +self+ for chaining
    def add_system_property(key, value)
      self << "-D#{key}=#{qualify_value(value)}"
      self
    end

    # Adds an option to the +JAVA_OPTS+.  Nothing is prepended to the key.  If the value is a +Pathname+, then prepends
    # +$PWD+ to the path (relative to the droplet root) to ensure that the path is always accurate.  Otherwise, uses
    # the value as-is.
    #
    # @param [String] key             the key of the option
    # @param [Pathname, String] value the value of the system property
    # @return [JavaOpts]              +self+ for chaining
    def add_option(key, value)
      self << "#{key}=#{qualify_value(value)}"
      self
    end

    # Returns the contents as an environment variable formatted as +JAVA_OPTS="<value1> <value2>"+
    #
    # @return [String] the contents as an environment variable
    def as_env_var
      "JAVA_OPTS=\"#{sort.join(' ')}\""
    end

    private

    def qualify_value(value)
      value.respond_to?(:relative_path_from) ? qualify_path(value) : value
    end

  end

end
