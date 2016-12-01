# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing Java debug options to an application.
    class Debug < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        enabled? ? "#{Debug.to_s.dash_case}=#{port}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_preformatted_options debug
      end

      private

      def debug
        "-agentlib:jdwp=transport=dt_socket,server=y,address=#{port},suspend=#{suspend}"
      end

      def enabled?
        @configuration['enabled']
      end

      def port
        @configuration['port'] || 8000
      end

      def suspend
        @configuration['suspend'] ? 'y' : 'n'
      end

    end

  end
end
