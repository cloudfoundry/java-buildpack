# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

module JavaBuildpack::Framework

  # Encapsulates the functionality for enabling the Postgres JDBC client.
  class PostgresqlJDBC < JavaBuildpack::Component::VersionedDependencyComponent

    def compile
      download_jar
      @droplet.additional_libraries << (@droplet.sandbox + jar_name)
    end

    def release
      @droplet.additional_libraries << (@droplet.sandbox + jar_name)
    end

    protected

    def supports?
      has_service? && !has_driver?
    end

    private

    def has_driver?
      (@application.root + '**/postgresql-*.jar').glob.any?
    end

    def has_service?
      @application.services.one_service? /postgres/
    end
  end

end
