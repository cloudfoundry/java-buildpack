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

  # Encapsulates the functionality for enabling zero-touch New Relic support.
  class NewRelicAgent < JavaBuildpack::Component::VersionedDependencyComponent

    def compile
      FileUtils.mkdir_p logs_dir

      download_jar
      @droplet.copy_resources
    end

    def release
      @droplet.java_opts
      .add_javaagent(@droplet.sandbox + jar_name)
      .add_system_property('newrelic.home', @droplet.sandbox)
      .add_system_property('newrelic.config.license_key', license_key)
      .add_system_property('newrelic.config.app_name', "'#{application_name}'")
      .add_system_property('newrelic.config.log_file_path', logs_dir)
    end

    protected

    def supports?
      @application.services.one_service? FILTER
    end

    private

    FILTER = /newrelic/.freeze

    def application_name
      @application.details['application_name']
    end

    def license_key
      @application.services.find_service(FILTER)['credentials']['licenseKey']
    end

    def logs_dir
      @droplet.sandbox + 'logs'
    end

  end

end
