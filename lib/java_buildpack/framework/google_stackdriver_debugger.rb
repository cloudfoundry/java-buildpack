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
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Google Cloud Debugger support.
    class GoogleStackdriverDebugger < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar false

        credentials = @application.services.find_service(FILTER, PRIVATE_KEY_DATA)['credentials']
        write_json_file credentials[PRIVATE_KEY_DATA]
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        java_opts = @droplet.java_opts

        java_opts
          .add_agentpath_with_props(@droplet.sandbox + 'cdbg_java_agent.so', '--logtostderr' => 1)
          .add_system_property('com.google.cdbg.auth.serviceaccount.enable', true)
          .add_system_property('com.google.cdbg.auth.serviceaccount.jsonfile', json_file)
          .add_system_property('com.google.cdbg.module', application_name)
          .add_system_property('com.google.cdbg.version', application_version)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, PRIVATE_KEY_DATA
      end

      FILTER = /google-stackdriver-debugger/

      PRIVATE_KEY_DATA = 'PrivateKeyData'

      private_constant :FILTER, :PRIVATE_KEY_DATA

      private

      def application_name
        @configuration['application_name'] || @application.details['application_name']
      end

      def application_version
        @configuration['application_version'] || @application.details['application_version']
      end

      def json_file
        @droplet.sandbox + 'svc.json'
      end

      def write_json_file(json_file_data)
        FileUtils.mkdir_p json_file.parent
        json_file.open(File::CREAT | File::WRONLY) do |f|
          f.write "#{Base64.decode64 json_file_data}\n"
          f.sync
          f
        end
      end

    end

  end
end
