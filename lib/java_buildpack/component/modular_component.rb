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

require 'fileutils'
require 'java_buildpack/component'
require 'java_buildpack/component/base_component'
require 'java_buildpack/repository/configured_item'
require 'java_buildpack/util/dash_case'
require 'tmpdir'

module JavaBuildpack
  module Component

    # A convenience base class for all components that are built modularly.  In addition to the functionality inherited
    # from +BaseComponent+ this class also ensures that the collection of modules are iterated over for each lifecycle
    # event.
    class ModularComponent < BaseComponent

      # Creates an instance.  In addition to the functionality inherited from +BaseComponent+, a +@sub_components+
      # instance variable is exposed.
      #
      # @param [Hash] context a collection of utilities used by components
      # @param [Block, nil] version_validator an optional version validation block
      def initialize(context, &version_validator)
        super(context, &version_validator)
        @sub_components = supports? ? sub_components(context) : []
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        supports? ? @sub_components.map(&:detect).flatten.compact : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        @sub_components.each(&:compile)
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        @sub_components.map(&:release)
        command
      end

      protected

      # The command for this component
      #
      # @return [void, String] components other than containers are not expected to return any value.  Container
      #                        components are expected to return the command required to run the application.
      def command
        raise "Method 'command' must be defined"
      end

      # The sub_components that make up this component
      #
      # @param [Hash] context the context of the component
      # @return [Array<BaseComponent>] a collection of +BaseComponent+s that make up the sub_components of this
      #                                component
      def sub_components(_context)
        raise "Method 'sub_components' must be defined"
      end

      # Returns a copy of the context, but with a subset of the original configuration
      #
      # @param [Hash] context the original context of the component
      # @param [String] key the key to get a subset of the context from
      # @return [Hash] context a copy of the original context, but with a subset of the original configuration
      def sub_configuration_context(context, key)
        c                 = context.clone
        c[:configuration] = context[:configuration][key]
        c
      end

      # Whether or not this component supports this application
      #
      # @return [Boolean] whether or not this component supports this application
      def supports?
        raise "Method 'supports?' must be defined"
      end

    end

  end
end
