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
        @droplet.security_providers.concat existing_security_providers(java_security) unless java_security.nil?
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        return if @droplet.java_home.java_9_or_later?
        @droplet.extension_directories << java_security.parent.parent + 'ext' unless java_security.nil?
      end

      private

      JAVA_9_SECURITY = 'conf/security/java.security'

      JRE_SECURITY = 'lib/security/java.security'

      SERVER_JRE_SECURITY = 'jre/lib/security/java.security'

      private_constant :JAVA_9_SECURITY, :JRE_SECURITY, :SERVER_JRE_SECURITY

      def existing_security_providers(existing_security)
        JavaBuildpack::Util::Properties.new(existing_security)
                                       .keep_if { |key, _| key =~ /security.provider/ }
                                       .sort_by { |entry| index(entry) }
                                       .map(&:last)
      end

      def index(entry)
        entry.first.match(/^security\.provider\.(\d+)/).captures.first.to_i
      end

      def java_security
        return java_9_security if @droplet.java_home.java_9_or_later? && java_9_security.exist?
        return jre_security if jre_security.exist?
        return server_jre_security if server_jre_security.exist?
        nil
      end

      def java_9_security
        @droplet.java_home.root + JAVA_9_SECURITY
      end

      def jre_security
        @droplet.java_home.root + JRE_SECURITY
      end

      def server_jre_security
        @droplet.java_home.root + SERVER_JRE_SECURITY
      end

    end

  end
end
