# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

require 'java_buildpack/util'

module JavaBuildpack::Util

  # Utilities for dealing with the the contents of +VCAP_SERVICES+
  class ServiceUtils

    # Find a service from the collection of services that matches a filter.  If no service matches, +nil+ is returned.
    #
    # @param [Hash<String, Object>] services the contents of +VCAP_SERVICES+
    # @param [Regexp] filter a filter used to match the service
    # @return [String, nil] the matched service contents, otherwise +nil+
    def self.find_service(services, filter)
      service = nil

      types = services.keys.select { |key| key =~ filter }
      fail "Exactly one service type matching '#{filter.source}' can be bound.  Found #{types.length}." if types.length > 1

      if types.length > 0
        instances = services[types[0]]
        fail "Exactly one service instance matching '#{filter.source}' can be bound.  Found #{instances.length}." if instances.length != 1

        service = instances[0]
      end

      service
    end

  end

end
