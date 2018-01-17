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

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/util/dash_case'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing Java JMX options to an application.
    class Jmx < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        enabled? ? "#{self.class.to_s.dash_case}=#{port}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "#{'----->'.red.bold} #{'JMX'.blue.bold} enabled on port #{port}"
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet
          .java_opts
          .add_system_property('java.rmi.server.hostname', '127.0.0.1')
          .add_system_property('com.sun.management.jmxremote.authenticate', false)
          .add_system_property('com.sun.management.jmxremote.ssl', false)
          .add_system_property('com.sun.management.jmxremote.port', port)
          .add_system_property('com.sun.management.jmxremote.rmi.port', port)
      end

      private

      def enabled?
        @configuration['enabled']
      end

      def port
        @configuration['port'] || 5000
      end

    end

  end
end
