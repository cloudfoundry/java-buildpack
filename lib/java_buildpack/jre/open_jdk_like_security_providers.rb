# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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
require 'java_buildpack/component/base_component'
require 'java_buildpack/jre'
require 'java_buildpack/util/properties'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for the OpenJDK-like security provider configuration
    class OpenJDKLikeSecurityProviders < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        OpenJDKLikeSecurityProviders.to_s.dash_case
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        unless existing_security.nil?
          existing = existing_security_providers existing_security

          @droplet.security_providers.insert 0, existing.shift
          @droplet.security_providers.concat existing
        end

        @droplet.security_providers.write_to new_security
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        unless existing_security.nil?
          @droplet.extension_directories << existing_security.parent.parent + 'ext'
        end

        @droplet.java_opts
                .add_system_property('java.ext.dirs', @droplet.extension_directories.as_paths)
                .add_system_property('java.security.properties', new_security)
      end

      private

      JRE_SECURITY = 'lib/security/java.security'.freeze

      SERVER_JRE_SECURITY = 'jre/lib/security/java.security'.freeze

      private_constant :JRE_SECURITY, :SERVER_JRE_SECURITY

      def existing_security
        return jre_security if jre_security.exist?
        return server_jre_security if server_jre_security.exist?
        nil
      end

      def existing_security_providers(existing_security)
        JavaBuildpack::Util::Properties.new(existing_security)
                                       .keep_if { |key, _| key =~ /security.provider/ }
                                       .sort_by { |entry| index(entry) }
                                       .map(&:last)
      end

      def index(entry)
        entry.first.match(/^security\.provider\.(\d+)/).captures.first.to_i
      end

      def jre_security
        @droplet.java_home.root + JRE_SECURITY
      end

      def new_security
        @droplet.sandbox + 'java.security'
      end

      def server_jre_security
        @droplet.java_home.root + SERVER_JRE_SECURITY
      end

    end

  end
end
