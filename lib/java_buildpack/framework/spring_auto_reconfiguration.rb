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

require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Spring
    # applications.
    class SpringAutoReconfiguration < JavaBuildpack::Component::VersionedDependencyComponent

      def initialize(context)
        super(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger SpringAutoReconfiguration
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        log_warning_scc_manual if spring_cloud_connectors?

        download_jar
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)

        log_warning_sar_scc_auto
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.additional_libraries << (@droplet.sandbox + jar_name)
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @configuration['enabled'] && spring? && !java_cfenv?
      end

      private

      def spring?
        (@droplet.root + '**/*spring-core*.jar').glob.any?
      end

      def java_cfenv?
        (@droplet.root + '**/*java-cfenv*.jar').glob.any?
      end

      def spring_cloud_connectors?
        (@droplet.root + '**/spring-cloud-cloudfoundry-connector*.jar').glob.any? ||
          (@droplet.root + '**/spring-cloud-spring-service-connector*.jar').glob.any?
      end

      def log_warning_scc_manual
        @logger.warn do
          'ATTENTION: The Spring Cloud Connectors library is present in your application. This library ' \
            'has been in maintenance mode since July 2019 and will stop receiving all updates after ' \
            'Dec 2022.'
        end
        @logger.warn do
          'Please migrate to java-cfenv immediately. See https://via.vmw.com/EiBW for migration instructions.' \
        end
      end

      def log_warning_sar_scc_auto
        @logger.warn do
          'ATTENTION: The Spring Auto Reconfiguration and shaded Spring Cloud Connectors libraries are ' \
            'being installed. These projects have been deprecated, are no longer receiving updates and should ' \
            'not be used going forward.'
        end
        @logger.warn do
          'If you are not using these libraries, set `JBP_CONFIG_SPRING_AUTO_RECONFIGURATION=\'{enabled: false}\'` ' \
            'to disable their installation and clear this warning message. The buildpack will switch its default ' \
            'to disable by default after Aug 2022. Spring Auto Reconfiguration and its shaded Spring Cloud ' \
            'Connectors will be removed from the buildpack after Dec 2022.'
        end
        @logger.warn do
          'If you are using these libraries, please migrate to java-cfenv immediately. ' \
            'See https://via.vmw.com/EiBW for migration instructions. Once you upgrade this message will go away.'
        end
      end
    end
  end
end
