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
require 'java_buildpack/framework'
require 'java_buildpack/util/service_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Framework

  # Encapsulates the functionality for enabling zero-touch New Relic support.
  class NewRelic < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('New Relic Agent', context)
    end

    def compile
      FileUtils.rm_rf home
      FileUtils.mkdir_p home
      FileUtils.mkdir_p logs_dir

      download_jar jar_name, home
      copy_resources
    end

    def release
      @application.java_opts
      .add_javaagent(home + jar_name)
      .add_system_property('newrelic.home', home)
      .add_system_property('newrelic.config.license_key', license_key)
      .add_system_property('newrelic.config.app_name', "'#{@vcap_application[NAME_KEY]}'")
      .add_system_property('newrelic.config.log_file_path', logs_dir)
    end

    protected

    def supports?
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
    end

    private

    NAME_KEY = 'application_name'.freeze

    SERVICE_NAME = /newrelic/.freeze

    def jar_name
      "#{@parsable_component_name}-#{@version}.jar"
    end

    def license_key
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)['credentials']['licenseKey']
    end

    def logs_dir
      home + 'logs'
    end

  end

end
