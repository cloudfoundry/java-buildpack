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

require 'fileutils'
require 'java_buildpack/component'

module JavaBuildpack
  module Component

    # An abstraction around the networking configuration provided to a droplet by components.
    #
    # A new instance of this type should be created once for the application.
    class Networking

      # @!attribute [rw] networkaddress_cache_ttl
      # @return [Integer] the number of seconds to cache the successful lookup
      attr_accessor :networkaddress_cache_ttl

      # @!attribute [rw] networkaddress_cache_negative_ttl
      # @return [Integer] the number of seconds to cache the failure for un-successful lookups
      attr_accessor :networkaddress_cache_negative_ttl

      # Write the networking configuration to a destination file
      #
      # @param [Pathname] destination the destination to write to
      # @return [Void]
      def write_to(destination)
        FileUtils.mkdir_p destination.parent

        destination.open(File::CREAT | File::APPEND | File::WRONLY) do |f|
          f.write "networkaddress.cache.ttl=#{@networkaddress_cache_ttl}\n" if @networkaddress_cache_ttl

          if @networkaddress_cache_negative_ttl
            f.write "networkaddress.cache.negative.ttl=#{networkaddress_cache_negative_ttl}\n"
          end
        end
      end

    end

  end
end
