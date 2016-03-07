# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2015 the original author or authors.
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
require 'java_buildpack/jre'

module JavaBuildpack
  module Jre

    # Encapsulates the detect, compile, and release functionality for the OpenJDK-like restart mechanism
    class OpenJDKLikeRestartMechanism < JavaBuildpack::Component::VersionedDependencyComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @droplet.copy_resources
        download_zip(false) if restart_type == 'agent'
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        configure_jre
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        true
      end

      private

      def restart_type
        ENV['JBP_OPENJDK_RESTART_MECHANISM_TYPE'] || @configuration['type']
      end

      def configure_jre
        type = restart_type
        case type
        when 'script'
          killjava_script
        when 'agent'
          killjava_agent
        when 'none'
          nil
        else @logger.debug { " Invalid RestartMechanism type: #{type}" }
        end
      end

      def killjava_script
        @droplet.java_opts
          .add_option('-XX:OnOutOfMemoryError', @droplet.sandbox + 'bin/killjava.sh')
      end

      def killjava_agent
        @droplet.java_opts
          .add_agentpath(@droplet.sandbox + 'lib/libjvmkill.so')
      end

    end

  end
end
