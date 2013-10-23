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

      matching_services = services.select { |key, service_instances| key =~ filter || service_instances_match(service_instances, filter) }
      fail "Exactly one service type matching '#{filter.source}' can be bound.  Found #{matching_services.length}." if matching_services.length > 1

      unless matching_services.empty?
        instances = matching_services.values[0]
        fail "Exactly one service instance matching '#{filter.source}' can be bound.  Found #{instances.length}." if instances.length != 1
        service = instances[0]
      end

      service
    end

    private

    def self.service_instances_match(service_instances, filter)
      service_instances.any? do |service_instance|
        match = service_instance['name'] =~ filter || service_instance['label'] =~ filter

        unless match
          tags = service_instance['tags']
          match = tags.any? { |tag| match = tag =~ filter } unless tags.nil?
        end

        match
      end
    end

  end

end
