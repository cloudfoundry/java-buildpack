# Encoding: utf-8
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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch New Relic support.
    class LanguageServerBinExecJDT < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        @droplet.copy_resources
        # FileUtils.mkdir_p 
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
#        credentials = @application.services.find_service(FILTER)['credentials']
#        java_opts   = @droplet.java_opts
#        configuration = {}

#       apply_configuration(credentials, configuration)
#       apply_user_configuration(credentials, configuration)
#       write_java_opts(java_opts, configuration)

#       java_opts.add_javaagent(@droplet.sandbox + jar_name)
#                .add_system_property('newrelic.home', @droplet.sandbox)
#       java_opts.add_system_property('newrelic.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
      end

      # Downloads a given TAR file and expands it.
      #
      # @param [String] version the version of the download
      # @param [String] uri the uri of the download
      # @param [Pathname] target_directory the directory to expand the TAR file to.  Defaults to the component's
      #                                    sandbox.
      # @param [String] name an optional name for the download and expansion.  Defaults to +@component_name+.
      # @return [Void]
      def download_tar(version, uri, target_directory = @droplet.sandbox, name = @component_name)
        download(version, uri, name) do |file|
          with_timing "Expanding #{name} to #{target_directory.relative_path_from(@droplet.root)}" do
            FileUtils.mkdir_p target_directory
            shell "tar x#{compression_flag(file)}f #{file.path} -C #{target_directory} 2>&1"
          end
        end
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.environment.key?(BINEXEC)
      end

      private

      BINEXEC = 'exec'.freeze

      private_constant :BINEXEC


    end

  end
end
