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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch JacCoCo support.
    class JacocoAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip false
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, ADDRESS)['credentials']
        properties = {
          'address' => credentials[ADDRESS],
          'output' => 'tcpclient',
          'sessionid' => '$CF_INSTANCE_GUID'
        }

        properties['excludes'] = credentials['excludes'] if credentials.key? 'excludes'
        properties['includes'] = credentials['includes'] if credentials.key? 'includes'
        properties['port'] = credentials['port'] if credentials.key? 'port'
        properties['output'] = credentials['output'] if credentials.key? 'output'

        @droplet.java_opts.add_javaagent_with_props(@droplet.sandbox + 'jacocoagent.jar', properties)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, ADDRESS
      end

      ADDRESS = 'address'

      FILTER = /jacoco/.freeze

      private_constant :ADDRESS, :FILTER

    end

  end
end
