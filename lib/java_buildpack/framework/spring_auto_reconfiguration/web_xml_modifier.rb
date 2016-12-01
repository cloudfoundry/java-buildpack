# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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

require 'java_buildpack/framework'
require 'rexml/document'
require 'rexml/formatters/pretty'

module JavaBuildpack
  module Framework

    # A class that encapsulates the modification of a +web.xml+ Servlet configuration file for the Auto-reconfiguration
    # framework.  The modifications of +web.xml+ consist of augmenting +contextInitializerClasses+.  The function starts
    # by enumerating the current +contextInitializerClasses+.  If none exist, a default configuration is created with no
    # value as the default. The +org.cloudfoundry.reconfiguration.spring.CloudProfileApplicationContextInitializer+,
    # +org.cloudfoundry.reconfiguration.spring.CloudPropertySourceApplicationContextInitializer+, and
    # +org.cloudfoundry.reconfiguration.spring.CloudAutoReconfigurationApplicationContextInitializer+ classes are then
    # added to the collection of classes.
    class WebXmlModifier

      # Creates a new instance of the modifier.
      #
      # @param [REXML::Document, String, IO] source the content of the +web.xml+ file to modify
      def initialize(source)
        @document = REXML::Document.new(source)
      end

      # Make modifications to the root context
      #
      # @return [Void]
      def augment_root_context
        augment web_app(@document), 'context-param' if context_loader_listener?
      end

      # Make modifications to the the servlet contexts
      #
      # @return [Void]
      def augment_servlet_contexts
        servlets.each do |servlet|
          augment servlet, 'init-param'
        end
      end

      # Returns a +String+ representation of the modified +web.xml+.
      #
      # @return [String] a +String+ representation of the modified +web.xml+.
      def to_s
        output = ''
        formatter.write(@document, output)
        output << "\n"

        output
      end

      private

      CONTEXT_INITIALIZER_ADDITIONAL = %w(
        org.cloudfoundry.reconfiguration.spring.CloudProfileApplicationContextInitializer
        org.cloudfoundry.reconfiguration.spring.CloudPropertySourceApplicationContextInitializer
        org.cloudfoundry.reconfiguration.spring.CloudAutoReconfigurationApplicationContextInitializer
      ).freeze

      CONTEXT_INITIALIZER_CLASSES = 'contextInitializerClasses'.freeze

      CONTEXT_LOADER_LISTENER = 'ContextLoaderListener'.freeze

      DISPATCHER_SERVLET = 'DispatcherServlet'.freeze

      private_constant :CONTEXT_INITIALIZER_CLASSES, :CONTEXT_LOADER_LISTENER, :DISPATCHER_SERVLET

      def augment(root, param_type)
        classes_string = xpath(root, "#{param_type}[param-name[contains(text(),
                               '#{CONTEXT_INITIALIZER_CLASSES}')]]/param-value/text()").first
        classes_string = create_param(root, param_type, CONTEXT_INITIALIZER_CLASSES, '') unless classes_string

        classes = classes_string.value.strip.split(/[,;\s]+/)
        classes = classes.concat CONTEXT_INITIALIZER_ADDITIONAL

        classes_string.value = classes.join(',')
      end

      def context_loader_listener?
        xpath(@document, "/web-app/listener/listener-class[contains(text(), '#{CONTEXT_LOADER_LISTENER}')]").any?
      end

      def create_param(root, param_type, name, value)
        load_on_startup = xpath(root, 'load-on-startup')
        if load_on_startup.any?
          param                                  = REXML::Element.new param_type
          load_on_startup.first.previous_sibling = param
        else
          param = REXML::Element.new param_type, root
        end
        param_name = REXML::Element.new 'param-name', param
        REXML::Text.new name, true, param_name

        param_value = REXML::Element.new 'param-value', param
        REXML::Text.new value, true, param_value
      end

      def formatter
        formatter         = REXML::Formatters::Pretty.new(4)
        formatter.compact = true
        formatter
      end

      def servlets
        xpath(@document, "/web-app/servlet[servlet-class[contains(text(), '#{DISPATCHER_SERVLET}')]]")
      end

      def web_app(root)
        xpath(root, '/web-app').first
      end

      def xpath(root, path)
        REXML::XPath.match(root, path)
      end

    end

  end
end
