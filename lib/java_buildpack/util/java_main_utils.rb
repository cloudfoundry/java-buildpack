# Encoding: utf-8
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

require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util'
require 'java_buildpack/util/properties'

module JavaBuildpack::Util

  # Java Main application utilities.
  class JavaMainUtils

    private_class_method :new

    class << self

      # Returns the Java main class name for the Java main configuration and given application directory or +nil+ if this
      # is not a Java main application.
      #
      # @param [JavaBuildpack::Component::Application] application the application
      # @param [Hash] configuration the Java main configuration or +nil+ if this is not provided
      # @return [String, nil] the Java main class name or +nil+ if there is no Java main class name
      def main_class(application, configuration = nil)
        config = configuration || JavaBuildpack::Util::ConfigurationUtils.load('java_main')
        config[MAIN_CLASS_PROPERTY] || manifest(application)[MANIFEST_PROPERTY]
      end

      # Return the manifest properties of the given application.
      #
      # @param [JavaBuildpack::Application::Application] application the application
      # @return [Properties] the properties from the application's manifest (if any)
      def manifest(application)
        manifest_file = application.root + 'META-INF/MANIFEST.MF'
        manifest_file = manifest_file.exist? ? manifest_file : nil
        JavaBuildpack::Util::Properties.new(manifest_file)
      end

      private

      MAIN_CLASS_PROPERTY = 'java_main_class'.freeze

      MANIFEST_PROPERTY = 'Main-Class'.freeze

    end

  end

end
