# Cloud Foundry Java Buildpack
# Copyright 2017 the original author or authors.
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
    # Encapsulates the functionality for enabling FusionReactor support.
    class FusionReactor < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context, &version_validator)
        @component_name                                  = 'FusionReactor'
        @application                                     = context[:application]
        @configuration                                   = context[:configuration]
        @droplet                                         = context[:droplet]
        return unless supports?
        @version = 'latest'
        @uri, @lib_uri, @password, @with_debug = find_agent
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar self.jar_name, @droplet.sandbox, @component_name
        return unless @with_debug

        download(@version, @lib_uri, lib_name) do |file|
          FileUtils.mkdir_p @droplet.sandbox
          FileUtils.cp_r(file.path, @droplet.sandbox + lib_name)
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        service     = @application.services.find_service FILTER
        credentials = service['credentials']
        java_opts   = @droplet.java_opts

        java_opts.add_system_property('frlicense', credentials[LICENSE_KEY])
        java_opts.add_system_property('fradminpassword', @password)

        credentials.each do |key, value|
          next if SYSTEM_KEYS.include? key
          java_opts.add_system_property(key, value)
        end

        props = {}
        props['name'] = credentials['instance_name'] || @application.details['application_name']
        props['address'] = credentials['instance_port'] || '8088'

        java_opts.add_javaagent_with_props(@droplet.sandbox + jar_name, props)

        return unless @with_debug
        java_opts.add_agentpath(@droplet.sandbox + lib_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        (architecture == 'x86_64' || architecture == 'i686') and (@application.services.one_service? FILTER, [LICENSE_KEY])
      end

      def jar_name
        'fusionreactor.jar'
      end

      def lib_name
        'libfrjvmti_x64.so'
      end

      private

      FILTER = /fusionreactor/

      LICENSE_KEY = 'license'

      SYSTEM_KEYS = [LICENSE_KEY, 'version', 'password', 'debug', 'agent_download_url', 'lib_download_url']

      private_constant :FILTER, :LICENSE_KEY

      def architecture
        `uname -m`.strip
      end

      def find_agent
        service     = @application.services.find_service FILTER
        credentials = service['credentials']

        password   = credentials['password']
        with_debug = credentials['debug']
        uri        = credentials['agent_download_url']
        lib_uri    = credentials['lib_download_url']

        if with_debug.nil?
          with_debug = true
        end

        unless uri
            uri = 'https://intergral-dl.s3.amazonaws.com/FR/Latest/fusionreactor.jar'
        end

        unless lib_uri
          lib_uri = 'https://intergral-dl.s3.amazonaws.com/FR/Latest/libfrjvmti_x64.so'
        end

        [uri, lib_uri, password, with_debug]
      end
    end
  end
end