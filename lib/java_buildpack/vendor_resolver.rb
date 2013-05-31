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

module JavaBuildpack

  # A resolver that selects values from a collection and chooses a default one if none is specified
  class VendorResolver

    # Resolves a vendor from a collection of vendors.  If the +candidate_vendor+ is not specified, and there is only a
    # single element in the collection, that vendor is returned.
    #
    # @param [String, nil] candidate_vendor the vendor to resolve
    # @param [Array<String>] vendors the collection of vendors to resolve against
    # @return [String] the resolved vendor
    # @raise if no vendor can be resolved
    # @raise if no +candidate_vendor+ is specified and not exactly 1 vendor is specified in the collection
    def self.resolve(candidate_vendor, vendors)
      if candidate_vendor.nil?
        resolved_vendor = pick_unique_vendor(vendors)
      elsif vendors.include? candidate_vendor
        resolved_vendor = candidate_vendor
      else
        raise "Invalid JRE vendor '#{candidate_vendor}'"
      end
      resolved_vendor
    end

    private

    def self.pick_unique_vendor(vendors)
      raise "There is no default vendor unless precisely one vendor is defined: #{vendors.join(', ')}" unless vendors.size == 1
      return vendors[0]
    end

  end
end
