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

require 'java_buildpack/diagnostics/logger_factory'
require 'java_buildpack/framework'
require 'java_buildpack/framework/spring_auto_reconfiguration/web_xml_modifier'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Framework

  # Encapsulates the detect, compile, and release functionality for enabling cloud auto-reconfiguration in Spring
  # applications.
  class SpringAutoReconfiguration < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('Spring Auto-reconfiguration', context)
      @logger = JavaBuildpack::Diagnostics::LoggerFactory.get_logger
    end

    def compile
      download_jar jar_name
      modify_web_xml
    end

    def release
    end

    protected

    def supports?
      Dir["#{@app_dir}/**/#{SPRING_JAR_PATTERN}"].any?
    end

    private

    SPRING_JAR_PATTERN = '*spring-core*.jar'.freeze

    WEB_XML = File.join 'WEB-INF', 'web.xml'.freeze

    def jar_name
      "#{@parsable_component_name}-#{@version}.jar"
    end

    def modify_web_xml
      web_xml = File.join @app_dir, WEB_XML

      if File.exists? web_xml
        puts '       Modifying /WEB-INF/web.xml for Auto Reconfiguration'
        @logger.debug { "  Original web.xml: #{File.read web_xml}" }

        modifier = File.open(web_xml) { |file| WebXmlModifier.new(file) }
        modifier.augment_root_context
        modifier.augment_servlet_contexts

        File.open(web_xml, 'w') do |file|
          file.write(modifier.to_s)
          file.fsync
        end

        @logger.debug { "  Modified web.xml: #{File.read web_xml}" }
      end
    end

  end

end
