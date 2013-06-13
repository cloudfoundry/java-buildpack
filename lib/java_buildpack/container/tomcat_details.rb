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

require 'java_buildpack/util/tokenized_version'
require 'java_buildpack/util/version_resolver'
require 'java_buildpack/container'
require 'open-uri'
require 'yaml'

module JavaBuildpack::Container

  # A class encapsulating details of the container required by the application.
  class TomcatDetails

    # @!attribute [r] version
    #   @return [String] the resolved Tomcat version based on configuration and the Tomcat versions in the index
    # @!attribute [r] uri
    #   @return [String] the resolved Tomcat URI based on on configuration and the Tomcat versions in the index
    attr_reader :version, :uri

    # Creates a new instance, passing in the Tomcat configuration.
    #
    # @param [Hash] tomcat_configuration the Tomcat configuration
    def initialize(tomcat_configuration)
      version = configured_version tomcat_configuration
      repository_root = repository_root tomcat_configuration
      versions = load_versions repository_root
      check_version_format version
      @version = JavaBuildpack::Util::VersionResolver.resolve(version, versions.keys)
      @uri = "#{versions[@version]}"
    rescue => e
      raise RuntimeError, "Tomcat container error: #{e.message}", e.backtrace
    end

    private

    VERSION_KEY = 'version'.freeze
    DEFAULT_VERSION = '+'.freeze
    REPOSITORY_ROOT_KEY = 'repository_root'.freeze
    INDEX_PATH = '/index.yml'.freeze

    def configured_version(tomcat_configuration)
      tomcat_configuration[VERSION_KEY] || DEFAULT_VERSION
    end

    def repository_root(tomcat_configuration)
      repository_root = tomcat_configuration[REPOSITORY_ROOT_KEY]
      raise "Tomcat repository root not configured in '#{tomcat_configuration}'" unless repository_root
      repository_root
    end

    def load_versions(repository_root)
      YAML.parse(open "#{repository_root}#{INDEX_PATH}").to_ruby
    end

    def check_version_format(version)
      tokenized_version = JavaBuildpack::Util::TokenizedVersion.new(version)
      raise "Malformed Tomcat version #{version}: too many version components" if tokenized_version[3]
    end

  end

end
