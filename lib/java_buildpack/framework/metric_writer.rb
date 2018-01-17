# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

    # Encapsulates the functionality for contributing a container-based security provider to an application.
    class MetricWriter < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, ACCESS_KEY, ENDPOINT)['credentials']

        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
        @droplet.java_opts
                .add_system_property('cloudfoundry.metrics.accessToken', credentials[ACCESS_KEY])
                .add_system_property('cloudfoundry.metrics.applicationId', @application.details['application_id'])
                .add_system_property('cloudfoundry.metrics.endpoint', credentials[ENDPOINT])
                .add_system_property('cloudfoundry.metrics.instanceId', '$CF_INSTANCE_GUID')
                .add_system_property('cloudfoundry.metrics.instanceIndex', '$CF_INSTANCE_INDEX')
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, ACCESS_KEY, ENDPOINT
      end

      ACCESS_KEY = 'access_key'

      ENDPOINT = 'endpoint'

      FILTER = /metrics-forwarder/

      private_constant :ACCESS_KEY, :ENDPOINT, :FILTER

    end

  end
end
