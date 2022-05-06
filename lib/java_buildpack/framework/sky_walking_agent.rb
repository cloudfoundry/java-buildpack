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

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling Sky walking APM support.
    class SkyWalkingAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_tar(true, @droplet.sandbox, 'sky_walking_agent')
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER, 'servers')['credentials']
        java_opts = @droplet.java_opts
        java_opts.add_javaagent(@droplet.sandbox + 'skywalking-agent.jar')

        application_name java_opts, credentials
        sample_n_per_3_secs java_opts, credentials
        span_limit_per_segment java_opts, credentials
        ignore_suffix java_opts, credentials
        open_debugging_class java_opts, credentials
        servers java_opts, credentials
        logging_level java_opts, credentials
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, 'servers'
      end

      private

      FILTER = /sky-?walking/.freeze

      private_constant :FILTER

      def servers(java_opts, credentials)
        servers = credentials['servers']
        raise "'servers' credential must be set" unless servers

        java_opts.add_system_property 'skywalking.collector.servers', servers
      end

      def application_name(java_opts, credentials)
        name = credentials['application-name'] || @configuration['default_application_name'] ||
          @application.details['application_name']
        java_opts.add_system_property('skywalking.agent.application_code', name.to_s)
      end

      def sample_n_per_3_secs(java_opts, credentials)
        sample_n_per_3_secs = credentials['sample-n-per-3-secs']
        java_opts.add_system_property 'skywalking.agent.sample_n_per_3_secs', sample_n_per_3_secs if sample_n_per_3_secs
      end

      def span_limit_per_segment(java_opts, credentials)
        span_lmt_per_seg = credentials['span-limit-per-segment']
        java_opts.add_system_property 'skywalking.agent.span_limit_per_segment', span_lmt_per_seg if span_lmt_per_seg
      end

      def ignore_suffix(java_opts, credentials)
        ignore_suffix = credentials['ignore-suffix']
        java_opts.add_system_property 'skywalking.agent.ignore_suffix', ignore_suffix if ignore_suffix
      end

      def open_debugging_class(java_opts, credentials)
        is_debug_class = credentials['is-open-debugging-class']
        java_opts.add_system_property 'skywalking.agent.is_open_debugging_class', is_debug_class if is_debug_class
      end

      def logging_level(java_opts, credentials)
        logging_level = credentials['logging-level']
        java_opts.add_system_property 'skywalking.logging.level', logging_level if logging_level
      end

    end

  end
end
