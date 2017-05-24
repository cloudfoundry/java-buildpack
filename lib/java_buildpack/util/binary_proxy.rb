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

require 'pathname'
require 'java_buildpack/util'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/logging/logger_factory'
require 'shellwords'
require 'yaml'

module JavaBuildpack
  module Util

    # Utility for loading configuration
    class BinaryProxy

      private_class_method :new

      class << self

        # Checks to see if a proxy exists for a URI. If it does, replace it
        # with the proxy uri.
        #
        # @param [String] URI to check for proxies
        # @return [String] The URI as-is or converted to the proxy if applicable
        def proxy_for(uri)
          repository = JavaBuildpack::Util::ConfigurationUtils.load('repository')
          return uri unless repository.key?('binary_proxies')
          repository['binary_proxies'].each do |proxy|
            return uri.sub(proxy['from'], proxy['to']) if uri.start_with?(proxy['from'])
          end
          uri
        end
      end
    end

  end

end
