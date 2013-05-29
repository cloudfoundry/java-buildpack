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

require 'java_buildpack/jre_properties'
require 'java_buildpack/jre_selector'
require 'java_buildpack/utils/format_duration'
require 'java_buildpack/utils/os'
require 'open-uri'

module JavaBuildpack

  # Encapsulates the compilation functionality in the Java buildpack
  class Compile

    # Creates a new instance, passing in the application directory and application cache directories used during
    # compilation
    #
    # @param [String] app_dir The application directory used during compilation
    # @param [String] app_cache_dir The application cache directory used during compilation
    def initialize(app_dir, app_cache_dir)
      @app_dir = app_dir
      @jre_properties = JreProperties.new(app_dir)
      jre_selector = JreSelector.new
      @uri = jre_selector.uri(@jre_properties.vendor, @jre_properties.version)
    end

    # The execution entry point for detection.  This method is responsible for identifying all of the components that are
    # that which to participate in the buildpack and returning their names.
    #
    # @return [void]
    def run
      download_start_time = Time.now
      print "-----> Downloading #{@jre_properties.vendor} #{@jre_properties.version} JRE from #{@uri} "

      open(@uri) do |file| # Use a global cache when available
        puts "(#{(Time.now - download_start_time).duration})"
        expand file
      end
    end

    private

    JAVA_HOME = '.java'

    def expand(file)
      expand_start_time = Time.now
      print "-----> Expanding JRE to #{JAVA_HOME} "

      java_home = File.join @app_dir, JAVA_HOME
      `rm -rf #{java_home}`
      `mkdir -p #{java_home}`

      expand_tar file, java_home

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def expand_tar(file, java_home)
      `tar xzf #{file.path} -C #{java_home} --strip 1 2>&1`
    end

    def expand_deb(file, java_home)
      if OS.linux?
        filter = '--wildcards "./usr/lib/jvm/java-*/*"'
      else
        filter = '"./usr/lib/jvm/java-*/*"'
      end

      `tar xzOf #{file.path} data.tar.gz | tar xz -C #{java_home} --strip 5 #{filter} 2>&1`
    end

  end
end
