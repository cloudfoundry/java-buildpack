# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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
require 'java_buildpack/util/shell'

module JavaBuildpack
  module Util

    # Utilities for dealing with Spring Boot applications
    class SpringBootUtils
      include JavaBuildpack::Util::Shell

      def initialize
        @jar_finder = JavaBuildpack::Util::JarFinder.new(/.*spring-boot-(\d.*)\.jar/)
      end

      # Caches the dependencies of a Thin Launcher application by execute the application with +dryRun+
      #
      # @param [Pathname] java_home the Java home to find +java+ in
      # @param [Pathname] application_root the root of the application to run
      # @param [Pathname] thin_root the root to cache cache dependencies at
      def cache_thin_dependencies(java_home, application_root, thin_root)
        shell "#{java_home + 'bin/java'} -Dthin.dryrun -Dthin.root=#{thin_root} -cp #{application_root} #{THIN_WRAPPER}"
      end

      # Indicates whether an application is a Spring Boot application
      #
      # @param [Application] application the application to search
      # @return [Boolean] +true+ if the application is a Spring Boot application, +false+ otherwise
      def is?(application)
        JavaBuildpack::Util::JavaMainUtils.manifest(application).key?(SPRING_BOOT_VERSION) ||
          @jar_finder.is?(application)
      end

      # Indicates whether an application is a Spring Boot Thin Launcher application
      #
      # @param [Application] application the application to search
      # @return [Boolean] +true+ if the application is a Spring Boot Thin Launcher application, +false+ otherwise
      def thin?(application)
        THIN_WRAPPER == JavaBuildpack::Util::JavaMainUtils.main_class(application)
      end

      # The lib directory of Spring Boot used by the application
      #
      # @param [Droplet] droplet the droplet to search
      # @return [String] the lib directory of Spring Boot used by the application
      def lib(droplet)
        candidate = manifest_lib_dir(droplet)
        return candidate if candidate&.exist?

        candidate = boot_inf_lib_dir(droplet)
        return candidate if candidate&.exist?

        candidate = web_inf_lib_dir(droplet)
        return candidate if candidate&.exist?

        candidate = lib_dir(droplet)
        return candidate if candidate&.exist?

        raise 'No lib directory found'
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

      SPRING_BOOT_LIB = 'Spring-Boot-Lib'

      SPRING_BOOT_VERSION = 'Spring-Boot-Version'

      THIN_WRAPPER = 'org.springframework.boot.loader.wrapper.ThinJarWrapper'

      private_constant :SPRING_BOOT_LIB, :SPRING_BOOT_VERSION

      def boot_inf_lib_dir(droplet)
        droplet.root + 'BOOT-INF/lib'
      end

      def manifest_lib_dir(droplet)
        value = JavaBuildpack::Util::JavaMainUtils.manifest(droplet)[SPRING_BOOT_LIB]
        value ? droplet.root + value : nil
      end

      def lib_dir(droplet)
        droplet.root + 'lib'
      end

      def web_inf_lib_dir(droplet)
        droplet.root + 'WEB-INF/lib'
      end

    end

  end
end
