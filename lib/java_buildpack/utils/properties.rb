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

  # A class representing a collection of Java properties
  class Properties < Hash

    # Create a new instance, populating it with values from a properties file
    #
    # @param [String] file the file to use for initialization
    def initialize(file)
      File.foreach(file) do |line|
        unless blank_line?(line) || comment_line?(line)
          if line =~ /^[\s]*([^:=\s]+)[\s]*[=:]?[\s]*([^:=\s]*)\s*$/
            self[$1] = $2
          end
        end
      end
    end

    private

    def blank_line?(line)
      line =~ /^[\s]*$/
    end

    def comment_line?(line)
      line =~ /^[\s]*[#!].*$/
    end

  end
end
