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

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        service     = @application.services.find_service FILTER
        credentials = service['credentials']
        java_opts   = @droplet.java_opts
        password, with_debug, license = find_agent

        java_opts.add_system_property('frlicense', license)
        java_opts.add_system_property('fradminpassword', password)

        credentials.each do |key, value|
          next if SYSTEM_KEYS.include? key
          java_opts.add_system_property(key, value)
        end

        props = {}
        props['name'] = credentials['instance_name'] || @application.details['application_name']
        props['address'] = credentials['instance_port'] || '8088'

        java_opts.add_javaagent_with_props(@droplet.sandbox + 'fusionreactor/' + jar_name, props)

        java_opts.add_agentpath(@droplet.sandbox + 'fusionreactor/' + lib_name) if with_debug
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

      SYSTEM_KEYS = [LICENSE_KEY, 'version', 'password', 'debug', 'instance_name', 'instance_port']

      private_constant :FILTER, :LICENSE_KEY

      def architecture
        `uname -m`.strip
      end

      def find_agent
        service     = @application.services.find_service FILTER
        credentials = service['credentials']

        password   = credentials['password']
        with_debug = credentials['debug']
        license    = credentials[LICENSE_KEY]

        if with_debug.nil?
          with_debug = true
        end

        [password, with_debug, license]
      end
    end
  end
end