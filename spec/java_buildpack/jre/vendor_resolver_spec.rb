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

require 'spec_helper'
require 'java_buildpack/jre/vendor_resolver'

module JavaBuildpack::Jre

  describe VendorResolver do

    VENDORS = [
      'openjdk'
    ]

    it 'raises an error if the candidate vendor is invalid' do
      expect { VendorResolver.resolve('invalid-vendor', VENDORS) }.to raise_error
    end

    it 'resolves a valid candidate vendor' do
      resolved_vendor = VendorResolver.resolve(VENDORS[0], VENDORS)
      expect(resolved_vendor).to eq(VENDORS[0])
    end

    it 'resolves a default vendor' do
      resolved_vendor = VendorResolver.resolve(nil, VENDORS)
      expect(resolved_vendor).to eq(VENDORS[0])
    end

    it 'fails to resolve a default vendor when this is ambiguous' do
      expect { VendorResolver.resolve(nil, ['openjdk', 'oracle']) }.to raise_error(/openjdk, oracle/)
    end

    it 'fails to resolve a default vendor when the collection is empty' do
      expect { VendorResolver.resolve(nil, []) }.to raise_error
    end

  end

end
