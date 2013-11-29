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

module JavaBuildpack::Util

  # A class representing a collection of Java properties
  class Properties < Hash

    # Create a new instance, populating it with values from a properties file
    #
    # @param [Pathname, nil] file_name the file to use for initialization. If no file is passed in, the instance is empty.
    def initialize(file_name)
      unless file_name.nil?
        contents = file_name.open { |file| file.read }
        contents.gsub! /[\r\n\f]+ /, ''

        contents.each_line do |line|
          unless blank_line?(line) || comment_line?(line)
            match_data = /^[\s]*([^:=\s]+)[\s]*[=:]?[\s]*(.*?)\s*$/.match(line)
            self[match_data[1]] = match_data[2] if match_data
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
