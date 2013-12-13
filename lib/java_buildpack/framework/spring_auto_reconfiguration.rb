# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/framework'
require 'java_buildpack/framework/spring_auto_reconfiguration/web_xml_modifier'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Spring
  # applications.
  class SpringAutoReconfiguration < JavaBuildpack::Component::VersionedDependencyComponent

    def initialize(context)
      super(context)
      @logger = JavaBuildpack::Logging::LoggerFactory.get_logger SpringAutoReconfiguration
    end

    def compile
      download_jar
      @droplet.additional_libraries << (@droplet.sandbox + jar_name)

      modify_web_xml
    end

    def release
      @droplet.additional_libraries << (@droplet.sandbox + jar_name)
    end

    protected

    def supports?
      (@droplet.root + '**/*spring-core*.jar').glob.any?
    end

    private

    def modify_web_xml
      web_xml = @droplet.root + 'WEB-INF/web.xml'

      if web_xml.exist?
        puts '       Modifying /WEB-INF/web.xml for Auto Reconfiguration'
        @logger.debug { "  Original web.xml: #{web_xml.read}" }

        modifier = web_xml.open { |file| WebXmlModifier.new(file) }
        modifier.augment_root_context
        modifier.augment_servlet_contexts

        web_xml.open('w') do |file|
          file.write(modifier.to_s)
          file.fsync
        end

        @logger.debug { "  Modified web.xml: #{web_xml.read}" }
      end
    end

  end

end
