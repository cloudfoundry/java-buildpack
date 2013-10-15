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

require 'java_buildpack/base_component'
require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/util/properties'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+ method.
  # This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle of Java
  # +main()+ applications.
  class Main < JavaBuildpack::BaseComponent

    def initialize(context)
      super('Java Main', context)
    end

    def detect
      main_class ? id : nil
    end

    def compile
    end

    def release
      java_string = File.join @java_home, 'bin', 'java'
      classpath_string = ContainerUtils.space(classpath)
      java_opts_string = ContainerUtils.space(ContainerUtils.to_java_opts_s(@java_opts))
      main_class_string = ContainerUtils.space(main_class)
      arguments_string = ContainerUtils.space(arguments)
      port_string = ContainerUtils.space(port)

      "#{java_string}#{classpath_string}#{java_opts_string}#{main_class_string}#{arguments_string}#{port_string}"
    end

    private

    ARGUMENTS_PROPERTY = 'arguments'.freeze

    CLASS_PATH_PROPERTY = 'Class-Path'.freeze

    def arguments
      @configuration[ARGUMENTS_PROPERTY]
    end

    def classpath
      classpath = ['.']
      classpath.concat ContainerUtils.libs(@app_dir, @lib_directory)
      classpath.concat manifest_class_path

      "-cp #{classpath.join(':')}"
    end

    def id
      'java-main'
    end

    def main_class
      JavaBuildpack::Util::JavaMainUtils.main_class(@app_dir, @configuration)
    end

    def manifest_class_path
      value = JavaBuildpack::Util::JavaMainUtils.manifest(@app_dir)[CLASS_PATH_PROPERTY]
      value.nil? ? [] : value.split(' ')
    end

    def port
      main_class =~ /^org\.springframework\.boot\.loader\.[JW]arLauncher$/ ? '--server.port=$PORT' : nil
    end

  end

end
