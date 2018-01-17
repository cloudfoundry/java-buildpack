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

    # Encapsulates the functionality for contributing custom Security Providers to an application.
    class JavaSecurity < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        JavaSecurity.to_s.dash_case
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @droplet.networking.write_to java_security
        @droplet.security_providers.write_to java_security
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts
                .add_system_property('java.ext.dirs', @droplet.extension_directories.as_paths)
                .add_system_property('java.security.properties', java_security)
      end

      private

      def java_security
        @droplet.sandbox + 'java.security'
      end

    end

  end
end
