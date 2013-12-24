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

require 'java_buildpack/component/base_component'
require 'java_buildpack/container'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+ method.
  # This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle of Java
  # +main()+ applications.
  class JavaMain < JavaBuildpack::Component::BaseComponent

    def detect
      main_class ? JavaMain.to_s.dash_case : nil
    end

    def compile
    end

    def release
      @droplet.additional_libraries.insert 0, @application.root
      manifest_class_path.each { |path| @droplet.additional_libraries << path }

      [
          "#{@droplet.java_home.root}/bin/java",
          @droplet.additional_libraries.as_classpath,
          @droplet.java_opts.sort.join(' '),
          main_class,
          arguments,
          port
      ].compact.join(' ')
    end

    private

    ARGUMENTS_PROPERTY = 'arguments'.freeze

    CLASS_PATH_PROPERTY = 'Class-Path'.freeze

    def arguments
      @configuration[ARGUMENTS_PROPERTY]
    end

    def main_class
      JavaBuildpack::Util::JavaMainUtils.main_class(@application, @configuration)
    end

    def manifest_class_path
      values = JavaBuildpack::Util::JavaMainUtils.manifest(@application)[CLASS_PATH_PROPERTY]
      values.nil? ? [] : values.split(' ').map { |value| @droplet.root + value }
    end

    def port
      main_class =~ /^org\.springframework\.boot\.loader\.(?:[JW]ar|Properties)Launcher$/ ? '--server.port=$PORT' : nil
    end

  end

end
