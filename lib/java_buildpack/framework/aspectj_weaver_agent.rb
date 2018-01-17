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
require 'java_buildpack/util/jar_finder'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for contributing AspectJ Runtime Weaving configuration an application.
    class AspectjWeaverAgent < JavaBuildpack::Component::BaseComponent

      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, +@version+ and +@uri+
      # instance variables are exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      def initialize(context)
        super(context)

        @jar_finder = JavaBuildpack::Util::JarFinder.new(/.*aspectjweaver-([\d].*)\.jar/)
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? "#{self.class.to_s.dash_case}=#{@jar_finder.version(@application)}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "#{'----->'.red.bold} #{'AspectJ'.blue.bold} #{version.to_s.blue} Runtime Weaving enabled"
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @droplet.java_opts.add_javaagent @jar_finder.is?(@application)
      end

      private

      def aop_xml_exist?
        (@application.root + 'BOOT-INF/classes/META-INF/aop.xml').exist? ||
          (@application.root + 'BOOT-INF/classes/org/aspectj/aop.xml').exist? ||
          (@application.root + 'META-INF/aop.xml').exist? ||
          (@application.root + 'org/aspectj/aop.xml').exist?
      end

      def enabled?
        @configuration['enabled']
      end

      def supports?
        enabled? && @jar_finder.is?(@application) && aop_xml_exist?
      end

      def version
        @jar_finder.version(@application)
      end

    end

  end
end
