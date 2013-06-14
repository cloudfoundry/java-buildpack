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

require 'java_buildpack/container'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/properties'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for Tomcat applications.
  class Tomcat

    # Creates an instance, passing in an arbitrary collection of options.
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [Hash] :configuration the properties
    def initialize(context)
      @app_dir = context[:app_dir]
      @java_opts = context[:java_opts]
      @configuration = context[:configuration]
    end

    # Detects whether this application is a Tomcat application.
    #
    # @return [String] returns +tomcat-<version>+ if and only if the application has a +WEB-INF+ directory, otherwise
    #                  returns +nil+
    def detect
      if web_inf?
        tomcat_version, tomcat_uri = find_tomcat
        id tomcat_version
      else
        nil
      end
    end

    # Does nothing as no transformations are currently performed for Tomcat applications.
    #
    # @return [void]
    def compile
    end

    # Creates the command to run the Tomcat application.
    #
    # @return [String] the command to run the application.
    def release
    end

    private

    WEB_INF_DIRECTORY = 'WEB-INF'.freeze

    def web_inf?
      File.exists? File.join(@app_dir, WEB_INF_DIRECTORY)
    end

    def find_tomcat
      JavaBuildpack::Repository::ConfiguredItem.find_item(@configuration) do |version|
        check_version_format version
      end
    rescue => e
      raise RuntimeError, "Tomcat container error: #{e.message}", e.backtrace
    end

    private

    def check_version_format(version)
      raise "Malformed Tomcat version #{version}: too many version components" if version[3]
    end

    def id(tomcat_version)
      "tomcat-#{tomcat_version}"
    end

  end

end
