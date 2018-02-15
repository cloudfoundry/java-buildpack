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
    class ContainerSecurityProvider < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.security_providers.insert 1, 'org.cloudfoundry.security.CloudFoundryContainerProvider'
        @droplet.additional_libraries << (@droplet.sandbox + jar_name) if @droplet.java_home.java_9_or_later?
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        if @droplet.java_home.java_9_or_later?
          @droplet.additional_libraries << (@droplet.sandbox + jar_name)
        else
          @droplet.extension_directories << @droplet.sandbox
        end

        unless key_manager_enabled.nil?
          @droplet.java_opts.add_system_property 'org.cloudfoundry.security.keymanager.enabled', key_manager_enabled
        end

        return if trust_manager_enabled.nil?
        @droplet.java_opts.add_system_property 'org.cloudfoundry.security.trustmanager.enabled', trust_manager_enabled
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def key_manager_enabled
        @configuration['key_manager_enabled']
      end

      def trust_manager_enabled
        @configuration['trust_manager_enabled']
      end

    end

  end
end
