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

require 'fileutils'
require 'java_buildpack/component'

module JavaBuildpack
  module Component

    # An abstraction around the security providers provided to a droplet by components.
    #
    # A new instance of this type should be created once for the application.
    class SecurityProviders < Array

      # Write the contents of the collection to a destination file
      #
      # @param [Pathname] destination the destination to write to
      # @return [Void]
      def write_to(destination)
        FileUtils.mkdir_p destination.parent

        destination.open(File::CREAT | File::APPEND | File::WRONLY) do |f|
          each_with_index { |security_provider, index| f.write "security.provider.#{index + 1}=#{security_provider}\n" }
        end
      end

    end

  end
end
