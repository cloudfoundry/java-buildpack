# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2015 the original author or authors.
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
require 'java_buildpack/util/qualify_path'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Dynatrace support.
    class DynaTraceAgent < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_zip false
        @droplet.copy_resources
        FileUtils.mkdir(home_dir)
        FileUtils.mv(@droplet.sandbox + 'agent/linux-x86-64/agent', home_dir)
        delete_extra_files
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
          .add_agentpath_with_props(agent_dir + 'libdtagent.so',
                                    name: application_name + '_' + profile_name,
                                    server: server)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'server'
      end

      private

      FILTER = /dynatrace/.freeze

      private_constant :FILTER

      def application_name
        @application.details['application_name']
      end

      def profile_name
        @application.services.find_service(FILTER)['credentials']['profile'] || 'Monitoring'
      end

      def agent_dir
        @droplet.sandbox + 'home/agent/lib64'
      end

      def delete_extra_files
        FileUtils.rm_rf(@droplet.sandbox + 'agent')
        FileUtils.rm_rf(@droplet.sandbox + 'init.d')
        FileUtils.rm_rf(@droplet.sandbox + 'com')
        FileUtils.rm_rf(@droplet.sandbox + 'org')
        FileUtils.rm_rf(@droplet.sandbox + 'META_INF')
        FileUtils.rm_f(@droplet.sandbox + 'YouShouldNotHaveUnzippedMe.txt')
      end

      def logs_dir
        @droplet.sandbox + 'home/log'
      end

      def home_dir
        @droplet.sandbox + 'home'
      end

      def server
        @application.services.find_service(FILTER)['credentials']['server']
      end

    end

  end
end
