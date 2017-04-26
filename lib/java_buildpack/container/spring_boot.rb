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

require 'java_buildpack/container'
require 'java_buildpack/container/dist_zip_like'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/spring_boot_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Spring Boot applications.
    class SpringBoot < JavaBuildpack::Container::DistZipLike

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @spring_boot_utils = JavaBuildpack::Util::SpringBootUtils.new
      end

      # (see JavaBuildpack::Container::DistZipLike#release)
      def release
        @droplet.environment_variables.add_environment_variable 'SERVER_PORT', '$PORT'
        super
      end

      protected

      # (see JavaBuildpack::Container::DistZipLike#id)
      def id
        "#{SpringBoot.to_s.dash_case}=#{version}"
      end

      # (see JavaBuildpack::Container::DistZipLike#supports?)
      def supports?
        start_script(root) && start_script(root).exist? && @spring_boot_utils.is?(@application)
      end

      private

      def version
        @spring_boot_utils.version @application
      end

    end

  end
end
