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

require 'java_buildpack/util'
require 'java_buildpack/util/repository_index'
require 'java_buildpack/util/version_resolver'
require 'yaml'

module JavaBuildpack::Util

  # A class encapsulating details of a type backed by a repository.
  class Details

    # @!attribute [r] version
    #   @return [TokenizedVersion] the resolved JRE version based on user input
    attr_reader :version

    # @!attribute [r] uri
    #   @return [String] the resolved JRE URI based on user input
    attr_reader :uri

    # Creates a new instance, passing in the application directory used during release
    #
    # @param [Hash] configuration the properties provided by the user
    def initialize(configuration)
      repository_root = Details.repository_root(configuration)
      version = Details.version(configuration)
      index = Details.index(repository_root)

      @version = VersionResolver.resolve(version, index.keys)
      @uri = index[@version.to_s]
    end

    private

    KEY_REPOSITORY_ROOT = 'repository_root'

    KEY_VERSION = 'version'

    SYS_PROP_VERSION = 'java.runtime.version'

    def self.index(repository_root)
      RepositoryIndex.new('openjdk-index', repository_root)
    end

    def self.repository_root(configuration)
      raise "A repository root must be specified as a key-value pair of '#{KEY_REPOSITORY_ROOT}'' to the URI of the repository." unless configuration.has_key? KEY_REPOSITORY_ROOT
      configuration[KEY_REPOSITORY_ROOT]
    end

    def self.version(configuration)
      version = configuration[SYS_PROP_VERSION]
      version = configuration[KEY_VERSION] if version.nil?
      version
    end

  end

end
