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

require 'base64'
require 'json'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Google Cloud Profiler support.
    class GoogleStackdriverProfiler < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar false

        write_json_file private_key_data
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        java_opts = @droplet.java_opts

        java_opts
          .add_agentpath_with_props(@droplet.sandbox + 'profiler_java_agent.so',
                                    '--logtostderr'          => 1,
                                    '-cprof_project_id'      => project_id,
                                    '-cprof_service'         => application_name,
                                    '-cprof_service_version' => application_version)

        @droplet.environment_variables.add_environment_variable 'GOOGLE_APPLICATION_CREDENTIALS', json_file
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, PRIVATE_KEY_DATA
      end

      FILTER = /google-stackdriver-profiler/

      PRIVATE_KEY_DATA = 'PrivateKeyData'

      private_constant :FILTER, :PRIVATE_KEY_DATA

      private

      def application_name
        @configuration['application_name'] || @application.details['application_name']
      end

      def application_version
        @configuration['application_version'] || @application.details['application_version']
      end

      def credentials
        @application.services.find_service(FILTER, PRIVATE_KEY_DATA)['credentials']
      end

      def private_key_data
        Base64.decode64 credentials[PRIVATE_KEY_DATA]
      end

      def project_id
        JSON.parse(private_key_data)['project_id']
      end

      def json_file
        @droplet.sandbox + 'svc.json'
      end

      def write_json_file(private_key_data)
        FileUtils.mkdir_p json_file.parent
        json_file.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{private_key_data}\n"
          f.sync
          f
        end
      end

    end

  end
end
