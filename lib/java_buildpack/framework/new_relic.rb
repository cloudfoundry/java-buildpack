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
require 'java_buildpack/util/resource_utils'
require 'java_buildpack/util/service_utils'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Framework

  # Encapsulates the functionality for enabling zero-touch New Relic support.
  class NewRelic < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('New Relic Agent', context)
    end

    def compile
      FileUtils.rm_rf new_relic_home
      FileUtils.mkdir_p new_relic_home
      FileUtils.mkdir_p File.join(new_relic_home, 'logs')

      download_jar jar_name, new_relic_home
      JavaBuildpack::Util::ResourceUtils.copy_resources('new-relic', new_relic_home)
    end

    def release
      @java_opts << "-javaagent:#{File.join NEW_RELIC_HOME, jar_name}"
      @java_opts << "-Dnewrelic.home=#{NEW_RELIC_HOME}"
      @java_opts << "-Dnewrelic.config.license_key=#{license_key}"
      @java_opts << "-Dnewrelic.config.app_name='#{@vcap_application[NAME_KEY]}'"
      @java_opts << "-Dnewrelic.config.log_file_path=#{File.join NEW_RELIC_HOME, 'logs'}"
    end

    protected

    def supports?
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)
    end

    private

    NAME_KEY = 'application_name'.freeze

    NEW_RELIC_HOME = '.new-relic'.freeze

    SERVICE_NAME = /newrelic/.freeze

    def jar_name
      "#{@parsable_component_name}-#{@version}.jar"
    end

    def license_key
      JavaBuildpack::Util::ServiceUtils.find_service(@vcap_services, SERVICE_NAME)['credentials']['licenseKey']
    end

    def new_relic_home
      File.join @app_dir, NEW_RELIC_HOME
    end

  end

end
