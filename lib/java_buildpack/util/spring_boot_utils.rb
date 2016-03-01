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

require 'pathname'
require 'java_buildpack/util'
require 'java_buildpack/util/jar_finder'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack
  module Util

    # Utilities for dealing with Spring Boot applications
    class SpringBootUtils

      def initialize
        @jar_finder = JavaBuildpack::Util::JarFinder.new(/.*spring-boot-([\d].*)\.jar/)
      end

      # Indicates whether an application is a Spring Boot application
      #
      # @param [Application] application the application to search
      # @return [Boolean] +true+ if the application is a Spring Boot application, +false+ otherwise
      def is?(application)
        JavaBuildpack::Util::JavaMainUtils.manifest(application).key?(SPRING_BOOT_VERSION) ||
          @jar_finder.is?(application)
      end

      def lib(droplet)
        return web_inf_lib_dir(droplet) if web_inf_lib_dir(droplet).exist?
        return lib_dir(droplet) if lib_dir(droplet).exist?
        fail('No lib directory found')
      end

      # The version of Spring Boot used by the application
      #
      # @param [Application] application the application to search
      # @return [String] the version of Spring Boot used by the application
      def version(application)
        JavaBuildpack::Util::JavaMainUtils.manifest(application)[SPRING_BOOT_VERSION] ||
          @jar_finder.version(application)
      end

      private

      SPRING_BOOT_VERSION = 'Spring-Boot-Version'.freeze

      private_constant :SPRING_BOOT_VERSION

      def lib_dir(droplet)
        droplet.root + 'lib'
      end

      def web_inf_lib_dir(droplet)
        droplet.root + 'WEB-INF/lib'
      end

    end

  end
end
