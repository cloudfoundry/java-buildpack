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

require 'java_buildpack/util'
require 'open3'

module JavaBuildpack
  module Util

    # A mixin that provides a +shell()+ command
    module Shell

      # A +system()+-like command that ensure that the execution fails if the command returns a non-zero exit code
      #
      # @param [Object] args The command to run
      # @return [Void]
      def shell(*args)
        Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
          out = stdout.gets nil
          err = stderr.gets nil

          unless wait_thr.value.success?
            puts "\nCommand '#{args.join ' '}' has failed"
            puts "STDOUT: #{out}"
            puts "STDERR: #{err}"

            raise
          end
        end
      end

    end
  end
end
