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

require 'java_buildpack/container'
require 'java_buildpack/container/dist_zip_like'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/ratpack_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Ratpack applications.
    class Ratpack < JavaBuildpack::Container::DistZipLike

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @ratpack_utils = JavaBuildpack::Util::RatpackUtils.new
      end

      protected

      # (see JavaBuildpack::Container::DistZipLike#id)
      def id
        "#{Ratpack.to_s.dash_case}=#{version}"
      end

      # (see JavaBuildpack::Container::DistZipLike#supports?)
      def supports?
        start_script(root)&.exist? && @ratpack_utils.is?(@application)
      end

      private

      def version
        @ratpack_utils.version @application
      end

    end

  end
end
