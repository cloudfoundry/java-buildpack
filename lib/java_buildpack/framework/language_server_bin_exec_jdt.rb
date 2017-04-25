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
require 'fileutils'
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch New Relic support.
    class LanguageServerBinExecJDT < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
        # Install LSP Server bin from from repository as a Versioned component
        @droplet.copy_resources
        FileUtils.mkdir_p @droplet.root + '.m2'
        FileUtils.cp_r(@droplet.sandbox + '.m2/.', @droplet.root + '.m2' )
        FileUtils.mkdir_p @droplet.root + 'di_ws_root'
        FileUtils.mkdir_p @droplet.root + 'jdt_ws_root'

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
