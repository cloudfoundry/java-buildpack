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
require 'java_buildpack/container'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomcat external configuration.
    class TomcatExternalConfiguration < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Container

      # (see JavaBuildpack::Component::VersionedDependencyComponent#initialize)
      def initialize(context, &version_validator)
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Tomcat External Configuration download location is always accessible'
        ) do
          super(context, &version_validator)
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        JavaBuildpack::Util::Cache::InternetAvailability.instance.available(
          true, 'The Tomcat External Configuration download location is always accessible', &method(:download_tar)
        )
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

    end

  end
end
