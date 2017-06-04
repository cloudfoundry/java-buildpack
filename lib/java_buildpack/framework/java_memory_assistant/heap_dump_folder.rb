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

require 'java_buildpack/component/base_component'
require 'java_buildpack/component/droplet'
require 'java_buildpack/framework'
require 'java_buildpack/framework/java_memory_assistant'

module JavaBuildpack
  module Framework

    # Encapsulates the integraton of the JavaMemoryAssistant to store generated heap dumps.
    class JavaMemoryAssistantHeapDumpFolder < JavaBuildpack::Component::BaseComponent

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used by the component
      def initialize(context)
        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger JavaMemoryAssistantHeapDumpFolder
        super(context)
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        true
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        # Nothing to do
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        heap_dump_folder = @configuration['heap_dump_folder']

        # If there is a bound volume service, use the heap_dump_folder under the volume's path
        service = find_heap_dump_volume_service
        if service
          volume_mount = service['volume_mounts'][0]
          container_dir = volume_mount['container_dir']
          mode = volume_mount['mode']

          raise "Volume mounted under '#{container_dir}' not in write mode" unless mode.to_s.include? 'w'

          heap_dump_folder = "#{container_dir}/#{heap_dump_folder}"
          @logger.info { "Using volume service mounted under '#{container_dir}' to store heap dumps" }
        end

        heap_dump_folder = 'dumps' unless heap_dump_folder

        @droplet.java_opts.add_system_property 'jma.heap_dump_folder', "\"#{heap_dump_folder}\""
        @logger.info { "Heap dumps will be stored under '#{heap_dump_folder}'" }
      end

      private

      # Matcher for service names or tags associated with the Java Memory Assistant
      FILTER = 'jbp-dumps'.freeze

      def find_heap_dump_volume_service
        @application.services.find_service FILTER
      end

    end
  end
end
