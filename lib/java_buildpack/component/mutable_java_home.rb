# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'java_buildpack/util/tokenized_version'

module JavaBuildpack
  module Component

    # An abstraction around the +JAVA_HOME+ path and +VERSION+ used by the droplet.  This implementation is mutable and
    # should be passed to any component that is a jre.
    #
    # A new instance of this type should be created once for the application.
    class MutableJavaHome

      # @!attribute [rw] root
      # @return [String] the root of the droplet's +JAVA_HOME+
      attr_accessor :root

      # @!attribute [rw] version
      # @return [JavaBuildpack::Util::TokenizedVersion] the tokenized droplet's +VERSION+
      attr_accessor :version

      # Whether or not the version of Java is 8 or later
      # @return [Boolean] +true+ if and only if the version is 1.8.0 or later
      def java_8_or_later?
        @version >= VERSION_8
      end

      VERSION_8 = JavaBuildpack::Util::TokenizedVersion.new('1.8.0').freeze

      private_constant :VERSION_8

    end

  end
end
