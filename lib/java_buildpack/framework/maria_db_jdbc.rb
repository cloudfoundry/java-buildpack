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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling the MariaDB JDBC client.
    class MariaDbJDBC < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        service? && !driver?
      end

      private

      def driver?
        %w[mariadb-java-client*.jar mysql-connector-java*.jar].any? do |candidate|
          (@application.root + '**' + candidate).glob.any?
        end
      end

      def service?
        [/mysql/, /mariadb/].any? { |filter| @application.services.one_service? filter, 'uri' }
      end
    end

  end
end
