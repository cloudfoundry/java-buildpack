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

require 'java_buildpack/component'
require 'java_buildpack/component/services'
require 'java_buildpack/util/filtering_pathname'
require 'json'

module JavaBuildpack
  module Component

    # An abstraction around the application as uploaded by the user.  This abstraction is intended to hide any
    # modifications made to the filesystem by other components.  Think of this as an immutable representation of the
    # application as it was uploaded.
    #
    # A new instance of this type should be created once for the application.
    class Application

      # @!attribute [r] details
      # @return [Hash] the parsed contents of the +VCAP_APPLICATION+ environment variable
      attr_reader :details

      # @!attribute [r] environment
      # @return [Hash] all environment variables except +VCAP_APPLICATION+ and +VCAP_SERVICES+.  Those values are
      #                available separately in parsed form.
      attr_reader :environment

      # @!attribute [r] root
      # @return [JavaBuildpack::Util::FilteringPathname] the root of the application's filesystem filtered so that it
      #                                                  only shows files that have been uploaded by the user
      attr_reader :root

      # @!attribute [r] services
      # @return [Hash] the parsed contents of the +VCAP_SERVICES+ environment variable
      attr_reader :services

      # Create a new instance of the application abstraction
      #
      # @param [Pathname] root the root of the application
      def initialize(root)
        initial = children(root)

        if Logging::LoggerFactory.instance.initialized
          log_file = JavaBuildpack::Logging::LoggerFactory.instance.log_file
          initial.delete(log_file)
        end

        @root = JavaBuildpack::Util::FilteringPathname.new(root, ->(path) { initial.member? path }, false)

        @environment = ENV.to_hash
        @details     = parse(@environment.delete('VCAP_APPLICATION'))
        @services    = Services.new(parse(@environment.delete('VCAP_SERVICES')))
      end

      private

      def children(root, s = Set.new)
        s << root
        root.children.each { |child| children(child, s) } if root.directory?
        s
      end

      def parse(input)
        input ? JSON.parse(input) : {}
      end

    end

  end
end
