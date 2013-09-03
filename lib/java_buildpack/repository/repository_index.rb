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

require 'java_buildpack/repository'
require 'java_buildpack/util/download_cache'
require 'java_buildpack/repository/version_resolver'
require 'rbconfig'
require 'yaml'

module JavaBuildpack::Repository

  # A repository index represents the index of repository containing various versions of a file.
  class RepositoryIndex

    # Creates a new repository index, populating it with values from an index file.
    #
    # @param [String] repository_root the root of the repository to create the index for
    def initialize(repository_root)
      @index = {}
      JavaBuildpack::Util::DownloadCache.new.get("#{canonical repository_root}#{INDEX_PATH}") do |file| # TODO: Use global cache #50175265
        @index.merge! YAML.load_file(file)
      end
    end

    # Finds a version of the file matching the given, possibly wildcarded, version.
    #
    # @param [String] version the possibly wildcarded version to find
    # @return [TokenizedVersion] the version of the file found
    # @return [String] the URI of the file found
    def find_item(version)
      version = VersionResolver.resolve(version, @index.keys)
      uri = @index[version.to_s]
      return version, uri # rubocop:disable RedundantReturn
    end

    private

    INDEX_PATH = '/index.yml'

    def architecture
      RbConfig::CONFIG['host_cpu']
    end

    def canonical(raw)
      raw
        .gsub(/\{platform\}/, platform)
        .gsub(/\{architecture\}/, architecture)
    end

    def linux_platform
      `lsb_release -cs`.strip
    end

    def osx_platform
      version = `sw_vers -productVersion`

      if version =~ /^10.8/
        return 'mountainlion'
      else
        raise "Unsupported OS X version '#{version}'"
      end
    end

    def platform
      if RbConfig::CONFIG['host_os'] =~ /darwin/i
        osx_platform
      else
        linux_platform
      end
    end

  end

end
