# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

# A mixin that provides a +shell()+ command
module JavaBuildpack::Util::Shell

  # A +system()+-like command that ensure that the execution fails if the command returns a non-zero exit code
  #
  # @param [String] command the command to run
  def shell(command)
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      if wait_thr.value != 0
        puts "\nCommand '#{command}' has failed"
        puts "STDOUT: #{stdout.gets}"
        puts "STDERR: #{stderr.gets}"

        fail
      end
    end
  end

end
